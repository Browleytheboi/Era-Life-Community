extends Resource
class_name CareerEngine

var gs

func _init(_gs):
	gs = _gs





func update_career(npc):
	if npc == null:
		return
	if not npc.alive:
		return




	if (
		gs != null
		and gs.career_runtime_engine != null
		and gs.career_contract_engine != null
	):
		gs.career_runtime_engine.sync_actor_from_legacy_job(
			npc,
			{
				"source": "career_engine.update_career_compatibility",
			}
		)

		if str(npc.job).strip_edges() == "":
			npc.unemployed_years += 1

		return




	if npc.age < 18:
		return

	if npc == gs.player:
		if npc.job == "":
			npc.unemployed_years += 1
			return

		if gs.workplace_engine != null:
			gs.workplace_engine.sync_existing_worker(npc)

		progress_job(npc)
		return

	if npc.job == "":
		assign_job(npc)
	else:
		if gs.workplace_engine != null:
			gs.workplace_engine.sync_existing_worker(npc)

		progress_job(npc)

	maybe_quit_or_switch(npc)





func get_available_jobs_for(person: Person) -> Array:
	var jobs:= []

	if person == null:
		return jobs
	if not person.alive:
		return jobs
	if person.age < 18:
		return jobs

	if (
		gs != null
		and gs.career_contract_engine != null
	):
		return (
			gs.career_contract_engine
			.legacy_job_names_for_actor(
				person,
				"full_time"
			)
		)

	for job_name in gs.era_engine.get_job_pool():
		jobs.append(str(job_name))

	return jobs

func get_available_part_time_jobs_for(
	person: Person
) -> Array:
	var jobs:= []

	if person == null:
		return jobs
	if not person.alive:
		return jobs
	if person.age < 16:
		return jobs
	if person.age >= 18:
		return jobs

	if (
		gs != null
		and gs.career_contract_engine != null
	):
		return (
			gs.career_contract_engine
			.legacy_job_names_for_actor(
				person,
				"part_time"
			)
		)

	for job_name in gs.era_engine.get_part_time_job_pool():
		jobs.append(str(job_name))

	return jobs

func get_famous_career_tracks_for(person: Person) -> Array:
	var tracks:= []
	if person == null:
		return tracks
	if not person.alive:
		return tracks

	for track_name in gs.era_engine.get_famous_career_tracks():
		var clean_track: String = str(track_name).strip_edges()
		if clean_track != "" and clean_track not in tracks:
			tracks.append(clean_track)

	var era_name: String = ""
	if gs != null and gs.era != null:
		era_name = str(gs.era.get("name", "")).strip_edges()

	if gs != null and gs.era_engine != null and gs.era_engine.supports_world_title_boxing():
		if era_name in ["Modern Era", "Future Era"]:
			if "Boxer" not in tracks:
				tracks.append("Boxer")

	return tracks

func get_career_browser_sections_for(person: Person) -> Dictionary:
	return {
		"part_time": get_available_part_time_jobs_for(person),
		"full_time": get_available_jobs_for(person),
		"famous": get_famous_career_tracks_for(person)
	}
func describe_job(
	person: Person
) -> Dictionary:
	if person == null or str(person.job).strip_edges() == "":
		return {
			"success": false,
			"text": "❌ I do not currently have a job."
		}

	var normalized_job_name: String = str(
		person.job
	).strip_edges()

	if (
		gs != null
		and gs.career_contract_engine != null
		and gs.career_contract_engine.has_method(
			"describe_available_job"
		)
	):
		var institutional_description: Dictionary = (
			gs.career_contract_engine
			.describe_available_job(
				person,
				normalized_job_name
			)
		)

		if bool(
			institutional_description.get(
				"success",
				false
			)
		):
			return institutional_description

	var coworkers_count: int = 0

	if gs.workplace_engine != null:
		coworkers_count = (
			gs.workplace_engine
			.get_coworkers(
				person
			)
			.size()
		)

	var job_type: String = "Full-Time"

	if person.age >= 16 and person.age < 18:
		job_type = "Part-Time"

	if normalized_job_name == "Retired":
		job_type = "Retired"

	var text: String = (
		"💼 Job: %s | Type: %s | Income: %d | "
		+ "Performance: %d | Experience: %d | Coworkers: %d"
	) % [
		normalized_job_name,
		job_type,
		int(person.income),
		int(person.job_performance),
		int(person.job_experience),
		coworkers_count
	]

	return {
		"success": true,
		"text": text
	}
func describe_available_job(person: Person, job_name: String) -> Dictionary:
	if person == null:
		return { "success": false, "text": "No active person is viewing this job."}

	var normalized_job_name: String = job_name.strip_edges()
	if normalized_job_name == "":
		return { "success": false, "text": "That job listing is unavailable."}

	var era_name:= "Unknown Era"
	if gs.era != null:
		era_name = str(gs.era.get("name", "Unknown Era"))

	if normalized_job_name == "Boxer":
		var boxer_eligibility_text: String = "Available now"
		if gs.boxing_engine == null or not gs.boxing_engine.can_start_boxing(person):
			boxer_eligibility_text = "Requires age 16+ and a modern/future boxing era."
		elif person.boxing_profile.get("is_boxer", false):
			boxer_eligibility_text = "Already active"

		var boxer_txt:= "BOXER\n\nRole: Boxer\nType: Famous Career Track\nExpected Lane: Combat Sports / Prizefighting\nEra: %s\nEligibility: %s\nEstimated Pay: Contract-driven purses, sponsorships, PPV upside\nPrestige Tier: Local Gym → Prospect → Contender → Champion → Undisputed\nStress Profile: Brutal physical wear, media pressure, ranking politics, sanctioning fees\nProjected Coworkers: Trainers, promoters, managers, sparring partners, sanctioning officials\nWorkplace Vibe: Gyms, arenas, weigh-ins, press conferences, and fight nights\nCompany Flavor: Promotional companies and sanctioning bodies now exist as contract-backed boxing organizations.\n\nStart from the bottom, build your record, climb the rankings, win franchise/interim/world belts, pay sanctioning fees, chase Ring Magazine, and become undisputed." % era_name

		return {
			"success": true,
			"text": boxer_txt,
			"popup_title": "FAMOUS CAREER: BOXER",
			"popup_text": boxer_txt,
			"job_name": normalized_job_name,
			"job_type": "Famous Career",
			"expected_lane": "Combat Sports / Prizefighting",
			"era_name": era_name,
			"eligibility_text": boxer_eligibility_text,
			"estimated_pay": "Contract-driven",
			"prestige_tier": "Local to Undisputed",
			"stress_profile": "Physical + financial + media pressure",
			"projected_coworkers": "Promoters, trainers, sanctioning officials",
			"workplace_vibe": "Fight camp and arena circuit",
			"company_style_flavor": "Contract-backed fight industry",
			"flavor_text": "This is no longer a generic famous career. This opens the boxing domain."
		}

	var is_part_time:= false
	var eligibility_text:= "Not currently available"

	if person.age < 16:
		is_part_time = true
		eligibility_text = "Unlocks at age 16"
	elif person.age >= 16 and person.age < 18:
		is_part_time = true
		if normalized_job_name in get_available_part_time_jobs_for(person):
			eligibility_text = "Available now"
		else:
			eligibility_text = "Part-time flow only at ages 16-17"
	else:
		is_part_time = false
		if normalized_job_name in get_available_jobs_for(person):
			eligibility_text = "Available now"
		else:
			eligibility_text = "Full-time flow only from age 18+"

	var expected_lane: String = _career_expected_lane_for_job(normalized_job_name, is_part_time)
	var prestige_tier: String = _career_prestige_tier_for_job(normalized_job_name, is_part_time)
	var stress_profile: String = _career_stress_profile_for_job(normalized_job_name, is_part_time)
	var projected_coworkers: String = _career_projected_coworkers_for_job(normalized_job_name, is_part_time)
	var workplace_vibe: String = _career_workplace_vibe_for_job(normalized_job_name, era_name, is_part_time)
	var company_style_flavor: String = _career_company_style_flavor_for_job(normalized_job_name, era_name, is_part_time)
	var flavor_text: String = _career_flavor_for_job(normalized_job_name, era_name, is_part_time)
	var estimated_pay: String = _salary_preview_for_job(normalized_job_name, is_part_time)

	var txt:= "%s\n\nRole: %s\nType: %s\nExpected Lane: %s\nEra: %s\nEligibility: %s\nEstimated Pay: %s\nPrestige Tier: %s\nStress Profile: %s\nProjected Coworkers: %s\nWorkplace Vibe: %s\nCompany Flavor: %s\n\n%s" % [
		normalized_job_name.to_upper(),
		normalized_job_name,
		"Part-Time" if is_part_time else "Full-Time",
		expected_lane,
		era_name,
		eligibility_text,
		estimated_pay,
		prestige_tier,
		stress_profile,
		projected_coworkers,
		workplace_vibe,
		company_style_flavor,
		flavor_text
	]

	return {
		"success": true,
		"text": txt,
		"popup_title": "OPPORTUNITY",
		"popup_text": txt,
		"job_name": normalized_job_name,
		"job_type": "Part-Time" if is_part_time else "Full-Time",
		"expected_lane": expected_lane,
		"era_name": era_name,
		"eligibility_text": eligibility_text,
		"estimated_pay": estimated_pay,
		"prestige_tier": prestige_tier,
		"stress_profile": stress_profile,
		"projected_coworkers": projected_coworkers,
		"workplace_vibe": workplace_vibe,
		"company_style_flavor": company_style_flavor,
		"flavor_text": flavor_text
	}
func _career_expected_lane_for_job(job_name: String, is_part_time: bool = false) -> String:
	if is_part_time:
		match job_name:
			"Tutor", "Library Assistant", "Apprentice", "Junior Clerk":
				return "Skill-building starter lane"
			"Retail Worker", "Fast Food Worker", "Restaurant Server":
				return "Service-entry fast lane"
			_:
				return "Early income lane"

	match job_name:
		"Doctor", "Lawyer", "Pilot", "Dentist", "Pharmacist", "Professor", "Judge", "Scientist":
			return "Elite professional lane"
		"Software Developer", "Financial Analyst", "Game Developer", "Engineer", "Architect", "Entrepreneur":
			return "High-skill growth lane"
		"Nurse", "Detective", "Teacher":
			return "Public-trust responsibility lane"
		"Retail Worker", "Fast Food Worker", "Restaurant Server", "Warehouse Associate", "Laborer", "Farmer":
			return "Working backbone lane"
		_:
			return "Standard career lane"


func _career_workplace_vibe_for_job(job_name: String, era_name: String, is_part_time: bool = false) -> String:
	if is_part_time:
		match job_name:
			"Retail Worker", "Fast Food Worker", "Restaurant Server":
				return "Fast, noisy, and customer-facing with little room to hide."
			"Tutor", "Library Assistant":
				return "Quiet, structured, and lightly supervised."
			"Apprentice", "Junior Clerk":
				return "Watchful, instructional, and built around proving yourself."
			_:
				return "Entry-level, supervised, and shaped by the pace of the era."

	match job_name:
		"Doctor", "Nurse", "Dentist", "Pharmacist":
			return "Clinical, urgent, and precision-heavy."
		"Lawyer", "Judge", "Financial Analyst":
			return "Polished, high-pressure, and reputation-sensitive."
		"Pilot":
			return "Disciplined, procedural, and mistake-intolerant."
		"Teacher", "Professor":
			return "People-facing, routine-driven, and emotionally demanding."
		"Software Developer", "Game Developer", "Engineer", "Architect", "Scientist":
			return "Focused, deadline-shaped, and mentally loaded."
		"Detective":
			return "Reactive, unpredictable, and full of visible pressure."
		"Retail Worker", "Fast Food Worker", "Restaurant Server":
			return "Fast, public, and constantly exposed to demand."
		"Warehouse Associate", "Laborer", "Farmer":
			return "Physical, repetitive, and endurance-based."
		"Entrepreneur":
			return "Volatile, self-driven, and built on risk."
		_:
			return "Structured by %s workplace expectations and the social pace of the era." % era_name


func _career_company_style_flavor_for_job(job_name: String, era_name: String, is_part_time: bool = false) -> String:
	if is_part_time:
		match job_name:
			"Retail Worker":
				return "The shop floor runs on smiles, stock, and whoever can survive the rush without cracking."
			"Fast Food Worker":
				return "Everything is speed, repetition, and keeping the line moving before somebody complains."
			"Restaurant Server":
				return "You live between table pressure, quick memory, and the mood of strangers."
			"Tutor":
				return "The work feels small on paper, but the room changes depending on whether people trust your mind."
			"Library Assistant":
				return "The atmosphere is quiet, but the rules, order, and little expectations still define the day."
			"Apprentice", "Junior Clerk":
				return "You are close enough to the real work to feel its shape, but still low enough to be watched."
			_:
				return "This lane feels like a starter doorway into the larger machinery of %s." % era_name

	match job_name:
		"Doctor":
			return "The room carries authority, urgency, and the weight of outcomes that matter more than comfort."
		"Lawyer":
			return "Every hallway feels polished, strategic, and quietly competitive."
		"Pilot":
			return "The culture is procedural, crisp, and built around confidence under scrutiny."
		"Dentist", "Pharmacist":
			return "The setting feels controlled, technical, and trust-dependent."
		"Professor", "Teacher":
			return "The workplace runs on knowledge, personalities, repetition, and whether people actually listen."
		"Scientist", "Engineer", "Architect", "Software Developer", "Game Developer":
			return "The job lives on output, ideas, and whether your brain can keep pace with what the era demands."
		"Nurse":
			return "The floor feels fast, emotional, and impossible to fake your way through for long."
		"Detective":
			return "The atmosphere is restless, suspicious, and shaped by what might go wrong next."
		"Financial Analyst":
			return "The culture rewards sharp thinking, clean presentation, and nerves that do not shake easily."
		"Entrepreneur":
			return "There is freedom in the lane, but the floor beneath it moves every day."
		"Retail Worker", "Fast Food Worker", "Restaurant Server", "Warehouse Associate", "Laborer", "Farmer":
			return "The workplace feels practical, demanding, and built around whoever can keep showing up."
		_:
			return "This role carries the flavor of a %s-era workplace trying to look stable while still demanding results." % era_name
func _career_prestige_tier_for_job(job_name: String, is_part_time: bool = false) -> String:
	if is_part_time:
		match job_name:
			"Tutor", "Library Assistant", "Apprentice", "Junior Clerk":
				return "Low-Mid"
			_:
				return "Entry Tier"

	match job_name:
		"Doctor", "Lawyer", "Pilot", "Dentist", "Pharmacist", "Professor", "Judge", "Scientist":
			return "Elite"
		"Software Developer", "Financial Analyst", "Game Developer", "Engineer", "Architect", "Entrepreneur", "Nurse", "Detective", "Teacher":
			return "High"
		"Retail Worker", "Fast Food Worker", "Restaurant Server", "Warehouse Associate", "Laborer", "Farmer":
			return "Working Tier"
		_:
			return "Solid Middle"

func _career_stress_profile_for_job(job_name: String, is_part_time: bool = false) -> String:
	if is_part_time:
		match job_name:
			"Retail Worker", "Fast Food Worker", "Restaurant Server":
				return "Moderate - busy shifts, customer pressure, fast pace."
			_:
				return "Low to Moderate - lighter responsibility, smaller stakes."

	match job_name:
		"Doctor", "Lawyer", "Pilot", "Detective", "Nurse":
			return "High - constant pressure, mistakes matter, performance is watched."
		"Teacher", "Professor", "Software Developer", "Financial Analyst", "Entrepreneur", "Engineer":
			return "Moderate - deadlines, output expectations, and mental load."
		"Retail Worker", "Fast Food Worker", "Warehouse Associate", "Laborer", "Farmer":
			return "Physical - repetition, fatigue, and long-shift wear."
		_:
			return "Balanced - manageable pressure with standard workplace expectations."

func _career_projected_coworkers_for_job(job_name: String, is_part_time: bool = false) -> String:
	if is_part_time:
		match job_name:
			"Retail Worker", "Fast Food Worker", "Restaurant Server":
				return "Busy team - usually 8-18 visible coworkers."
			"Library Assistant", "Tutor", "Apprentice":
				return "Small crew - usually 2-8 visible coworkers."
			_:
				return "Mixed staff - usually 4-12 visible coworkers."

	match job_name:
		"Doctor", "Nurse", "Pharmacist", "Dentist":
			return "Dense staff ecosystem - usually 12-40 visible coworkers."
		"Software Developer", "Financial Analyst", "Professor", "Teacher", "Lawyer":
			return "Structured team - usually 6-20 visible coworkers."
		"Warehouse Associate", "Factory Worker", "Laborer", "Retail Worker":
			return "Large floor presence - usually 15-60 visible coworkers."
		_:
			return "Typical workplace mix - usually 5-18 visible coworkers."

func _career_flavor_for_job(job_name: String, era_name: String, is_part_time: bool = false) -> String:
	var role_text:= job_name
	if is_part_time:
		role_text = "part-time %s role" % job_name

	match era_name:
		"Ancient Era":
			return "This %s lives close to barter, hierarchy, and survival. Reputation travels fast here, and steady work can anchor a family line." % role_text
		"Medieval Era":
			return "This %s sits inside guild pressure, local politics, and status-by-duty. The work carries routine, hierarchy, and public visibility." % role_text
		"Industrial Era":
			return "This %s runs on clocks, output, and discipline. Factories, offices, and crowded labor systems make consistency matter more than charm." % role_text
		"Modern Era":
			return "This %s moves through credentials, managers, performance reviews, and upward mobility. It is stable, readable, and tied to identity." % role_text
		"Future Era":
			return "This %s exists in a fast, networked labor world where efficiency, adaptation, and systems fluency shape who rises." % role_text
		_:
			return "This %s can build income, experience, status, and visible workplace momentum over time." % role_text

func _salary_preview_for_job(job_name: String, is_part_time: bool = false) -> String:
	var era_name:= ""
	if gs.era != null:
		era_name = str(gs.era.get("name", ""))

	var min_pay:= 0
	var max_pay:= 0

	if is_part_time:
		match era_name:
			"Ancient Era":
				min_pay = 10
				max_pay = 80
			"Medieval Era":
				min_pay = 20
				max_pay = 120
			"Industrial Era":
				min_pay = 120
				max_pay = 900
			"Modern Era":
				min_pay = 4000
				max_pay = 18000
			"Future Era":
				min_pay = 12000
				max_pay = 36000
			_:
				min_pay = 2000
				max_pay = 12000
	else:
		match era_name:
			"Ancient Era":
				min_pay = 40
				max_pay = 400
			"Medieval Era":
				min_pay = 80
				max_pay = 900
			"Industrial Era":
				min_pay = 800
				max_pay = 6000
			"Modern Era":
				match job_name:
					"Doctor", "Lawyer", "Pilot", "Dentist", "Pharmacist", "Professor":
						min_pay = 70000
						max_pay = 180000
					"Software Developer", "Financial Analyst", "Entrepreneur", "Game Developer":
						min_pay = 50000
						max_pay = 140000
					"Fast Food Worker", "Retail Worker", "Restaurant Server", "Warehouse Associate":
						min_pay = 22000
						max_pay = 42000
					_:
						min_pay = 30000
						max_pay = 90000
			"Future Era":
				min_pay = 90000
				max_pay = 320000
			_:
				min_pay = 25000
				max_pay = 60000

	if gs.economy_engine != null:
		return "%s - %s per year" % [
			gs.economy_engine.format_money(min_pay),
			gs.economy_engine.format_money(max_pay)
		]

	return "%d - %d per year" % [min_pay, max_pay]

func apply_for_job(
	person: Person,
	job_name: String
) -> Dictionary:
	if person == null:
		return {
			"success": false,
			"text": "Nobody is applying."
		}

	if (
		gs != null
		and gs.career_contract_engine != null
		and gs.career_runtime_engine != null
	):
		return (
			gs.career_contract_engine
			.apply_for_legacy_job(
				person,
				job_name,
				"full_time",
				{
					"source": (
						"career_engine.apply_for_job_compatibility"
					),
				}
			)
		)




	if not person.alive:
		return {
			"success": false,
			"text": "Dead people cannot apply for jobs."
		}

	if person.age < 18:
		return {
			"success": false,
			"text": "Full-time jobs unlock at age 18."
		}

	if person.job != "":
		return {
			"success": false,
			"text": (
				"I already have a full-time job as a %s."
				% person.job
			)
		}

	var jobs = get_available_jobs_for(person)

	if jobs.is_empty():
		return {
			"success": false,
			"text": "No full-time jobs are available in this era."
		}

	if job_name == "" or job_name not in jobs:
		job_name = jobs [randi() % jobs.size()]

	_assign_job(
		person,
		job_name,
		true,
		false
	)

	var txt = "I got hired as a %s." % job_name

	gs.narrative_engine.log_event(
		person,
		{
			"type": "text",
			"text": txt
		}
	)

	if gs.event_bus != null:
		gs.event_bus.emit(
			ActionEventTypes.JOB_HIRED,
			{
				"npc_id": person.id,
				"text": "%s got hired as a %s."
				% [
					person.first_name,
					job_name
				],
				"job_name": job_name
			}
		)

	return {
		"success": true,
		"text": txt
	}

func apply_for_part_time_job(person: Person, job_name: String) -> Dictionary:
	if person == null:
		return { "success": false, "text": "\n❌\n Nobody is applying."

}
	if (
		gs != null
		and gs.career_contract_engine != null
		and gs.career_runtime_engine != null
	):
		return (
			gs.career_contract_engine
			.apply_for_legacy_job(
				person,
				job_name,
				"part_time",
				{
					"source": (
						"career_engine.apply_for_part_time_job_compatibility"
					),
				}
			)
		)
	if not person.alive:
		return { "success": false, "text": " Dead people cannot apply for jobs."}
	if person.age < 16:
		return { "success": false, "text": " Part-time jobs unlock at age 16."}
	if person.age >= 18:
		return { "success": false, "text": " Part-time jobs are only for ages 16-17 in this flow."}
	if person.job != "":
		return { "success": false, "text": "\n❌\n I already have a job as a %s."

% person.job}
	var jobs = get_available_part_time_jobs_for(person)
	if jobs.is_empty():
		return { "success": false, "text": "\n❌\n No part-time jobs are available in this era."

}
	if job_name == "" or job_name not in jobs:
		job_name = jobs [randi() % jobs.size()]
	_assign_job(person, job_name, true, true)
	var txt = "\n💼\n I got hired part-time as a %s." \

% job_name
	gs.narrative_engine.log_event(person, {
		"type": "text",
		"text": txt
	})
	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.JOB_HIRED, {
			"npc_id": person.id,
			"text": "%s got hired part-time as a %s." % [person.first_name, job_name],
			"job_name": job_name
		})
	return { "success": true, "text": txt}

func work_shift(person: Person, intensity: String = "normal") -> Dictionary:
	if person == null:
		return { "success": false, "text": "❌ Nobody worked."}
	if (
		gs != null
		and gs.career_contract_engine != null
		and gs.career_runtime_engine != null
	):
		return (
			gs.career_contract_engine
			.perform_activity(
				person,
				"",
				{
					"source": (
						"career_engine.work_shift_compatibility"
					),
					"intensity": intensity,
				}
			)
		)
	if person.age < 18:
		return { "success": false, "text": "❌ Full-time jobs unlock at age 18."}
	if person.job == "":
		return { "success": false, "text": "❌ I do not currently have a full-time job."}
	if gs.workplace_engine == null or not gs.workplace_engine.has_coworkers(person):
		return { "success": false, "text": "❌ I need coworkers before the workplace can run properly."}

	var perf_delta:= 0
	var stress_delta:= 0.0
	var sat_delta:= 0
	var hours:= 8
	var bonus:= 0
	var label:= "worked normally"

	match intensity:
		"hard":
			perf_delta = 12
			stress_delta = 10.0
			sat_delta = -3
			hours = 11
			bonus = int(person.income * 0.03)
			label = "worked hard"

		"slack":
			perf_delta = -12
			stress_delta = -2.0
			sat_delta = 3
			hours = 6
			label = "slacked off"

		_:
			perf_delta = 4
			stress_delta = 4.0
			sat_delta = 0
			hours = 8
			label = "worked normally"

	person.job_performance = clamp(person.job_performance + perf_delta, 0, 100)
	person.work_stress = clamp(person.work_stress + stress_delta, 0.0, 100.0)
	person.satisfaction = clamp(person.satisfaction + sat_delta, 0, 100)
	person.hours_worked_last_year += hours

	if bonus > 0:
		person.bank_balance += bonus

	var txt = "🧾 I %s as a %s." % [label, person.job]
	if bonus > 0:
		txt += " I earned an extra %d." % bonus

	gs.narrative_engine.log_event(person, {
		"type": "text",
		"text": txt
	})

	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.JOB_WORKED, {
			"npc_id": person.id,
			"text": "%s %s as a %s." % [person.first_name, label, person.job],
			"job_name": person.job,
			"intensity": intensity
		})

	return { "success": true, "text": txt}


func ask_for_raise(person: Person) -> Dictionary:
	if person == null:
		return { "success": false, "text": "❌ Nobody asked for a raise."}
	if (
		gs != null
		and gs.career_contract_engine != null
		and gs.career_runtime_engine != null
	):
		return (
			gs.career_contract_engine
			.evaluate_raise(
				person,
				{
					"source": (
						"career_engine.ask_for_raise_compatibility"
					),
				}
			)
		)
	if person.job == "":
		return { "success": false, "text": "❌ I do not currently have a full-time job."}

	if person.age < 18:
		return { "success": false, "text": "❌ Full-time jobs unlock at age 18."}
	if gs.workplace_engine == null or not gs.workplace_engine.has_coworkers(person):
		return { "success": false, "text": "❌ Raises are only meaningful once the workplace is populated."}

	var chance:= 20
	chance += int(person.job_performance / 2.0)
	chance += min(person.job_experience * 4, 20)
	chance -= int(person.work_stress / 8.0)
	chance = clamp(chance, 5, 90)

	if randi() % 100 < chance:
		var amount = randi_range(1200, 9000)
		person.income += amount
		person.satisfaction = clamp(person.satisfaction + 5, 0, 100)

		var txt = "💸 I asked for a raise and got %d more per year." % amount
		gs.narrative_engine.log_event(person, {
			"type": "text",
			"text": txt
		})

		if gs.event_bus != null:
			gs.event_bus.emit(ActionEventTypes.JOB_RAISE_GRANTED, {
				"npc_id": person.id,
				"text": "%s got a raise at work." % person.first_name,
				"job_name": person.job,
				"raise_amount": amount
			})

		return { "success": true, "text": txt}

	person.satisfaction = clamp(person.satisfaction - 3, 0, 100)
	return { "success": false, "text": "❌ I asked for a raise, but they said no."}


func quit_job(person: Person) -> Dictionary:
	if person == null:
		return { "success": false, "text": "❌ Nobody quit."}
	if (
		gs != null
		and gs.career_runtime_engine != null
	):
		return (
			gs.career_runtime_engine
			.commit_quit(
				person,
				{
					"source": (
						"career_engine.quit_job_compatibility"
					),
				}
			)
		)
	if person.job == "":
		return { "success": false, "text": "❌ I do not currently have a full-time job."}

	var old_job = person.job

	if gs.workplace_engine != null:
		gs.workplace_engine.unregister_worker(person)

	person.job = ""
	person.income = 0
	person.job_performance = 50
	person.job_experience = 0
	person.work_stress = 0.0
	person.hours_worked_last_year = 0
	person.current_workplace_id = ""
	person.coworkers.clear()

	var txt = "🚪 I quit my job as a %s." % old_job
	gs.narrative_engine.log_event(person, {
		"type": "text",
		"text": txt
	})

	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.JOB_QUIT, {
			"npc_id": person.id,
			"text": "%s quit working as a %s." % [person.first_name, old_job],
			"job_name": old_job
		})

	return { "success": true, "text": txt}





func assign_job(npc):
	if npc == null:
		return

	if gs != null and gs.royalty_engine != null and gs.royalty_engine.has_method("_formal_royal_job_for"):
		var royal_job: String = str(gs.royalty_engine._formal_royal_job_for(npc)).strip_edges()
		if royal_job != "":
			if gs.royalty_engine.has_method("_sync_royal_job_identity"):
				gs.royalty_engine._sync_royal_job_identity(npc)
			return

	if npc.job != "":
		return
	if npc.age >= 18:
		var selected:= pick_job_for(npc)
		if selected == "":
			return
		_assign_job(npc, selected, false, false)
		return
	if npc.age >= 16:
		var jobs = get_available_part_time_jobs_for(npc)
		if jobs.is_empty():
			return
		var selected = jobs [randi() % jobs.size()]
		_assign_job(npc, selected, false, true)
func pick_job_for(person: Person) -> String:
	if person == null:
		return ""

	if gs != null and gs.royalty_engine != null and gs.royalty_engine.has_method("_formal_royal_job_for"):
		var royal_job: String = str(gs.royalty_engine._formal_royal_job_for(person)).strip_edges()
		if royal_job != "":
			return royal_job

	var raw_jobs:= get_available_jobs_for(person)
	if raw_jobs.is_empty():
		return ""

	var social_class: String = _normalized_social_class_for_jobs(person)
	var jobs: Array = []

	for raw_job in raw_jobs:
		var job_name: String = str(raw_job).strip_edges()
		if job_name == "":
			continue

		var bucket: String = _job_prestige_bucket(job_name)
		if bucket == "royal" and social_class not in ["Royal", "Noble"]:
			continue

		jobs.append(job_name)

	if jobs.is_empty():
		return ""

	var weighted_jobs:= _build_weighted_job_pool_for(person, jobs)
	if weighted_jobs.is_empty():
		return str(jobs [randi() % jobs.size()])

	return str(weighted_jobs [randi() % weighted_jobs.size()])

func reseed_household_jobs_for_class(anchor: Person) -> void:
	if anchor == null:
		return
	var family: Array = []
	var seen: Dictionary = {}
	_append_unique_household_member(family, seen, anchor)
	for pid in anchor.parents:
		var parent: Person = gs.get_npc_by_id(int(pid))
		if parent == null:
			continue
		_append_unique_household_member(family, seen, parent)
		if parent.partner != null:
			_append_unique_household_member(family, seen, parent.partner)
		for sid in parent.children:
			_append_unique_household_member(family, seen, gs.get_npc_by_id(int(sid)))
		for gpid in parent.parents:
			var grandparent: Person = gs.get_npc_by_id(int(gpid))
			if grandparent == null:
				continue
			_append_unique_household_member(family, seen, grandparent)
			if grandparent.partner != null:
				_append_unique_household_member(family, seen, grandparent.partner)
			for ggpid in grandparent.parents:
				_append_unique_household_member(family, seen, gs.get_npc_by_id(int(ggpid)))
	for member in family:
		if member == null:
			continue
		if not member.alive:
			continue
		if member.age < 18:
			continue
		if member.age >= 65 and str(member.job).strip_edges() == "Retired":
			continue
		var social_class: String = _normalized_social_class_for_jobs(member)
		if _job_prestige_bucket(str(member.job)) == "royal" and social_class not in ["Royal", "Noble"]:
			member.job = ""

		var next_job:= pick_job_for(member)
		if next_job == "":
			continue

		member.job = next_job
		sync_or_seed_existing_job_state(member, false)

func _append_unique_household_member(family: Array, seen: Dictionary, person: Person) -> void:
	if person == null:
		return
	var pid:= int(person.id)
	if pid <= 0:
		return
	if seen.has(pid):
		return
	seen [pid] = true
	family.append(person)

func _build_weighted_job_pool_for(person: Person, jobs: Array) -> Array:
	var weighted: Array = []
	if person == null:
		return weighted
	for raw_job in jobs:
		var job_name:= str(raw_job)
		var weight:= _job_weight_for_social_class(person, job_name)
		for i in range(max(weight, 1)):
			weighted.append(job_name)
	return weighted

func _job_weight_for_social_class(person: Person, job_name: String) -> int:
	var social_class:= _normalized_social_class_for_jobs(person)
	var bucket:= _job_prestige_bucket(job_name)
	match social_class:
		"Royal":
			match bucket:
				"royal": return 18
				"elite": return 12
				"upper": return 7
				"middle": return 3
				"working": return 1
				"lower": return 1
		"Noble":
			match bucket:
				"royal": return 10
				"elite": return 14
				"upper": return 8
				"middle": return 3
				"working": return 1
				"lower": return 1
		"Elite":
			match bucket:
				"royal": return 4
				"elite": return 14
				"upper": return 8
				"middle": return 3
				"working": return 1
				"lower": return 1
		"Upperclass":
			match bucket:
				"royal": return 2
				"elite": return 9
				"upper": return 12
				"middle": return 5
				"working": return 1
				"lower": return 1
		"Merchant":
			match bucket:
				"elite": return 6
				"upper": return 9
				"middle": return 10
				"working": return 3
				"lower": return 1
				"royal": return 1
		"Middle Class":
			match bucket:
				"elite": return 3
				"upper": return 6
				"middle": return 12
				"working": return 5
				"lower": return 1
				"royal": return 1
		"Commoner":
			match bucket:
				"elite": return 2
				"upper": return 4
				"middle": return 10
				"working": return 8
				"lower": return 3
				"royal": return 1
		"Working Class":
			match bucket:
				"elite": return 1
				"upper": return 2
				"middle": return 5
				"working": return 12
				"lower": return 7
				"royal": return 1
		"Peasant":
			match bucket:
				"elite": return 1
				"upper": return 1
				"middle": return 3
				"working": return 10
				"lower": return 12
				"royal": return 1
		"Lower Class":
			match bucket:
				"elite": return 1
				"upper": return 1
				"middle": return 2
				"working": return 8
				"lower": return 14
				"royal": return 1
		_:
			match bucket:
				"elite": return 2
				"upper": return 4
				"middle": return 8
				"working": return 7
				"lower": return 3
				"royal": return 1
	return 1

func _normalized_social_class_for_jobs(person: Person) -> String:
	if person == null:
		return "Commoner"
	if person.is_royal:
		return "Royal"
	var raw:= str(person.social_class).strip_edges()
	match raw:
		"Royal", "Noble", "Merchant", "Peasant", "Commoner", "Lower Class", "Working Class", "Middle Class", "Upperclass", "Elite":
			return raw
	return "Commoner"

func _job_prestige_bucket(job_name: String) -> String:
	var text:= str(job_name).to_lower()
	if text.contains("king") or text.contains("queen") or text.contains("emperor") or text.contains("empress") or text.contains("pharaoh") or text.contains("prince") or text.contains("princess") or text.contains("duke") or text.contains("duchess") or text.contains("lord") or text.contains("lady") or text.contains("consort") or text.contains("regent") or text.contains("chief") or text.contains("sovereign") or text.contains("heir"):
		return "royal"
	if text.contains("governor") or text.contains("minister") or text.contains("general") or text.contains("judge") or text.contains("lawyer") or text.contains("doctor") or text.contains("surgeon") or text.contains("architect") or text.contains("scientist") or text.contains("professor") or text.contains("engineer") or text.contains("banker") or text.contains("analyst") or text.contains("manager") or text.contains("director") or text.contains("producer") or text.contains("diplomat") or text.contains("developer") or text.contains("programmer") or text.contains("rights lawyer"):
		return "elite"
	if text.contains("merchant") or text.contains("trader") or text.contains("shopkeeper") or text.contains("teacher") or text.contains("accountant") or text.contains("journalist") or text.contains("designer") or text.contains("photographer") or text.contains("actor") or text.contains("music") or text.contains("streamer") or text.contains("content creator") or text.contains("chef") or text.contains("pharmacist") or text.contains("detective"):
		return "upper"
	if text.contains("mechanic") or text.contains("electrician") or text.contains("plumber") or text.contains("constable") or text.contains("police") or text.contains("firefighter") or text.contains("paramedic") or text.contains("nurse") or text.contains("clerk") or text.contains("operator") or text.contains("secretary") or text.contains("typist") or text.contains("tailor") or text.contains("barber"):
		return "middle"
	if text.contains("worker") or text.contains("laborer") or text.contains("miner") or text.contains("dock") or text.contains("warehouse") or text.contains("seamstress") or text.contains("mill") or text.contains("machinist") or text.contains("boilermaker") or text.contains("sweeper") or text.contains("carrier") or text.contains("milkman") or text.contains("construction") or text.contains("security") or text.contains("courier"):
		return "working"
	return "lower"
func sync_or_seed_existing_job_state(npc: Person,
		ensure_coworkers: bool = true) -> void:
	if npc == null:
		return
	if not npc.alive:
		return
	if npc.job == "":
		return

	var royal_job: String = ""
	if gs != null and gs.royalty_engine != null and gs.royalty_engine.has_method("_formal_royal_job_for"):
		royal_job = str(gs.royalty_engine._formal_royal_job_for(npc)).strip_edges()
	if royal_job != "":
		if gs.royalty_engine.has_method("_sync_royal_job_identity") and str(npc.job).strip_edges() != royal_job:
			gs.royalty_engine._sync_royal_job_identity(npc)
		if gs.workplace_engine != null:
			gs.workplace_engine.unregister_worker(npc)
		npc.current_workplace_id = ""
		npc.coworkers.clear()
		return

	if npc.job == "Retired":
		npc.income = max(float(npc.income), 0.0)
		npc.current_workplace_id = ""
		npc.coworkers.clear()
		return
	var is_part_time:= npc.age >= 16 and npc.age < 18
	if float(npc.income) <= 0.0:
		npc.income = _roll_era_salary(npc.job, is_part_time)
	if int(npc.satisfaction) <= 0:
		npc.satisfaction = randi_range(35, 75)
	if int(npc.job_performance) <= 0:
		npc.job_performance = randi_range(40, 65)
	if int(npc.job_experience) < 0:
		npc.job_experience = 0
	if float(npc.work_stress) <= 0.0:
		npc.work_stress = randf_range(10.0, 45.0 if is_part_time else 55.0)
	if gs.workplace_engine != null and npc.age >= 16:
		gs.workplace_engine.register_worker(npc, npc.job)
		if ensure_coworkers:
			gs.workplace_engine.ensure_minimum_coworkers(npc, 2)


func _assign_job(npc: Person, job_name: String, emit_bus_event: bool, is_part_time: bool = false) -> void:
	if npc == null:
		return

	var previous_job: String = str(npc.job).strip_edges()
	var clean_job_name: String = str(job_name).strip_edges()
	if clean_job_name == "":
		return

	var is_new_job_assignment: bool = previous_job != clean_job_name

	npc.job = clean_job_name
	npc.income = _roll_era_salary(clean_job_name, is_part_time)
	npc.satisfaction = randi_range(35, 75)
	npc.job_performance = randi_range(40, 65)
	npc.job_experience = 0
	npc.unemployed_years = 0
	npc.work_stress = randf_range(10.0, 35.0) if is_part_time else randf_range(15.0, 55.0)
	npc.hours_worked_last_year = 0

	if gs.workplace_engine != null and npc.age >= 16:
		gs.workplace_engine.register_worker(npc, clean_job_name)
		gs.workplace_engine.ensure_minimum_coworkers(npc, 2)

	if is_new_job_assignment and _should_log_job_start_for(npc, clean_job_name):
		_mark_job_start_logged_for(npc, clean_job_name)

		var npc_diary_text: String = "At %d, I started working%s as a %s." % [
			int(npc.age),
			" part-time" if is_part_time else "",
			clean_job_name
		]

		if gs.narrative_engine != null:
			gs.narrative_engine.log_event(npc, {
				"type": "job_start",
				"job": clean_job_name,
				"job_name": clean_job_name,
				"text": npc_diary_text,
				"life_diary_text": npc_diary_text,
				"force_first_person_memory": true,
				"source": "career_engine",
				"career_log_key": _job_start_log_key(npc, clean_job_name),
				"suppress_world_feed": true
			})

		_career_log_player_family_career_update(npc, "job_hired", clean_job_name, {
			"is_part_time": is_part_time
		})

	if emit_bus_event and gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.JOB_HIRED, {
			"npc_id": npc.id,
			"text": "%s got hired%s as a %s." % [
				npc.first_name,
				" part-time" if is_part_time else "",
				clean_job_name
			],
			"job_name": clean_job_name
		})
func _job_start_log_registry() -> Dictionary:
	if gs == null:
		return {}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var raw: Variant = gs.scenario_state.get("career_job_start_log_registry", {})
	var registry: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	gs.scenario_state ["career_job_start_log_registry"] = registry
	return registry


func _job_start_log_key(npc: Person, job_name: String) -> String:
	if npc == null:
		return ""

	var clean_job: String = str(job_name).strip_edges().to_lower()
	var year_value: int = int(gs.year) if gs != null else 0

	return "%d:%s:%d" % [
		int(npc.id),
		clean_job,
		year_value
	]


func _should_log_job_start_for(npc: Person, job_name: String) -> bool:
	if npc == null:
		return false

	var clean_job: String = str(job_name).strip_edges()
	if clean_job == "":
		return false

	var key: String = _job_start_log_key(npc, clean_job)
	if key == "":
		return false

	var registry: Dictionary = _job_start_log_registry()
	if bool(registry.get(key, false)):
		return false

	return true


func _mark_job_start_logged_for(npc: Person, job_name: String) -> void:
	if npc == null:
		return

	var key: String = _job_start_log_key(npc, job_name)
	if key == "":
		return

	var registry: Dictionary = _job_start_log_registry()
	registry [key] = true

	var person_key: String = str(int(npc.id))
	var person_jobs: Array = []
	if typeof(registry.get(person_key, [])) == TYPE_ARRAY:
		person_jobs = registry.get(person_key, [])

	var clean_job: String = str(job_name).strip_edges()
	if clean_job != "" and clean_job not in person_jobs:
		person_jobs.append(clean_job)

	registry [person_key] = person_jobs
	gs.scenario_state ["career_job_start_log_registry"] = registry

func _roll_era_salary(job_name: String, is_part_time: bool = false) -> float:
	var era_name:= ""
	if gs.era != null:
		era_name = str(gs.era.get("name", ""))
	if is_part_time:
		match era_name:
			"Ancient Era":
				return randf_range(10, 80)
			"Medieval Era":
				return randf_range(20, 120)
			"Industrial Era":
				return randf_range(120, 900)
			"Modern Era":
				return randf_range(4000, 18000)
			"Future Era":
				return randf_range(12000, 36000)
			_:
				return randf_range(2000, 12000)

	match era_name:
		"Ancient Era":
			return randf_range(40, 400)
		"Medieval Era":
			return randf_range(80, 900)
		"Industrial Era":
			return randf_range(800, 6000)
		"Modern Era":
			match job_name:
				"Doctor", "Lawyer", "Pilot", "Dentist", "Pharmacist", "Professor":
					return randf_range(70000, 180000)
				"Software Developer", "Financial Analyst", "Entrepreneur", "Game Developer":
					return randf_range(50000, 140000)
				"Fast Food Worker", "Retail Worker", "Restaurant Server", "Warehouse Associate":
					return randf_range(22000, 42000)
				_:
					return randf_range(30000, 90000)
		"Future Era":
			return randf_range(90000, 320000)
		_:
			return randf_range(25000, 60000)





func progress_job(npc):
	if npc == null:
		return
	if npc.job == "":
		return

	_process_yearly_payroll(npc)

	npc.job_experience += 1
	npc.work_stress = clamp(npc.work_stress + randf_range(-3.0, 6.0), 0.0, 100.0)
	npc.job_performance = clamp(
		npc.job_performance + randi_range(-4, 6) + int(npc.smarts / 40),
		0,
		100
	)

	if npc.work_stress > 70.0:
		npc.satisfaction = clamp(npc.satisfaction - randi_range(3, 8), 0, 100)
	else:
		npc.satisfaction = clamp(npc.satisfaction + randi_range(-3, 4), 0, 100)

	_maybe_promote(npc)
	_maybe_raise_passive(npc)
	_maybe_fire(npc)

	npc.hours_worked_last_year = 0


func _process_yearly_payroll(npc: Person) -> void:
	var pay:= int(npc.income)

	if npc.job_performance >= 85:
		pay += int(npc.income * 0.12)
	elif npc.job_performance >= 70:
		pay += int(npc.income * 0.05)
	elif npc.job_performance <= 20:
		pay -= int(npc.income * 0.1)

	pay = max(pay, 0)
	npc.bank_balance += pay

	if npc == gs.player:
		var txt = "💰 I earned %d this year from my full-time job as a %s." % [pay, npc.job]
		gs.narrative_engine.log_event(npc, {
			"type": "text",
			"text": txt
		})


func _maybe_promote(npc: Person) -> void:
	if npc.job_experience < 3:
		return
	if npc.job_performance < 80:
		return
	if randi() % 100 >= 16:
		return

	var old_job = npc.job
	npc.income += randi_range(4000, 18000)
	npc.satisfaction = clamp(npc.satisfaction + 8, 0, 100)

	var npc_diary_text: String = "At %d, I was promoted at work as a %s." % [
		int(npc.age),
		old_job
	]

	if gs.narrative_engine != null:
		gs.narrative_engine.log_event(npc, {
			"type": "text",
			"text": npc_diary_text,
			"life_diary_text": npc_diary_text,
			"force_first_person_memory": true,
			"source": "career_engine",
			"category": "career",
			"event_name": "job_promoted",
			"job_name": old_job,
			"suppress_world_feed": true
		})

	_career_log_player_family_career_update(npc, "job_promoted", old_job)

	var txt = "%s was promoted at work as a %s." % [npc.first_name, old_job]

	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.JOB_PROMOTED, {
			"npc_id": npc.id,
			"text": txt,
			"job_name": old_job
		})


func _maybe_raise_passive(npc: Person) -> void:
	if npc.satisfaction > 60 and randi() % 100 < 18:
		var amount = randi_range(1000, 6000)
		npc.income += amount

		if gs.event_bus != null:
			gs.event_bus.emit(ActionEventTypes.JOB_RAISE_GRANTED, {
				"npc_id": npc.id,
				"text": "%s received a raise as a %s." % [npc.first_name, npc.job],
				"job_name": npc.job,
				"raise_amount": amount
			})


func _maybe_fire(npc: Person) -> void:
	if npc.job_performance > 15:
		return
	if randi() % 100 >= 12:
		return

	var old_job = npc.job

	if gs.workplace_engine != null:
		gs.workplace_engine.unregister_worker(npc)

	npc.job = ""
	npc.income = 0
	npc.job_performance = 50
	npc.work_stress = 0.0
	npc.current_workplace_id = ""
	npc.coworkers.clear()

	var npc_diary_text: String = "At %d, I got fired from my job as a %s." % [
		int(npc.age),
		old_job
	]

	if gs.narrative_engine != null:
		gs.narrative_engine.log_event(npc, {
			"type": "text",
			"text": npc_diary_text,
			"life_diary_text": npc_diary_text,
			"force_first_person_memory": true,
			"source": "career_engine",
			"category": "career",
			"event_name": "job_fired",
			"job_name": old_job,
			"suppress_world_feed": true
		})

	_career_log_player_family_career_update(npc, "job_fired", old_job)

	if gs.event_bus != null:
		gs.event_bus.emit(ActionEventTypes.JOB_FIRED, {
			"npc_id": npc.id,
			"text": "%s got fired from a %s job." % [npc.first_name, old_job],
			"job_name": old_job
		})
func _career_log_player_family_career_update(npc: Person, event_name: String, job_name: String, context: Dictionary = {}) -> void:
	if gs == null or gs.player == null or npc == null:
		return
	if int(npc.id) == int(gs.player.id):
		return
	if gs.narrative_engine == null:
		return

	var relation_label: String = _career_relation_label_to_player(npc)
	if relation_label == "":
		return

	var clean_job: String = str(job_name).strip_edges()
	if clean_job == "":
		clean_job = "work"

	var text: String = ""
	match event_name:
		"job_hired":
			text = "My %s started working%s as a %s." % [
				relation_label,
				" part-time" if bool(context.get("is_part_time", false)) else "",
				clean_job
			]
		"job_promoted":
			text = "My %s was promoted at work as a %s." % [
				relation_label,
				clean_job
			]
		"job_fired":
			text = "My %s got fired from a %s job." % [
				relation_label,
				clean_job
			]
		_:
			return

	var key: String = "career_family_diary|%d|%d|%s|%s" % [
		int(gs.year),
		int(npc.id),
		event_name,
		clean_job.to_lower()
	]

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var registry_raw: Variant = gs.scenario_state.get("career_family_diary_registry", {})
	var registry: Dictionary = registry_raw if typeof(registry_raw) == TYPE_DICTIONARY else {}
	if bool(registry.get(key, false)):
		return

	registry [key] = true
	gs.scenario_state ["career_family_diary_registry"] = registry

	gs.narrative_engine.log_event(gs.player, {
		"type": "text",
		"text": text,
		"source": "career_engine",
		"category": "career",
		"event_name": event_name,
		"npc_id": int(npc.id),
		"job_name": clean_job,
		"relationship_label": relation_label,
		"personally_relevant": true,
		"diary_scope": "family",
		"suppress_world_feed": true
	})


func _career_relation_label_to_player(npc: Person) -> String:
	if gs == null or gs.player == null or npc == null:
		return ""

	var player: Person = gs.player
	var npc_id: int = int(npc.id)

	if npc_id in player.parents:
		return "father" if str(npc.gender).to_lower() == "male" else "mother" if str(npc.gender).to_lower() == "female" else "parent"

	if npc_id in player.children:
		return "son" if str(npc.gender).to_lower() == "male" else "daughter" if str(npc.gender).to_lower() == "female" else "child"

	if player.partner != null and npc_id == int(player.partner.id):
		return "husband" if str(npc.gender).to_lower() == "male" else "wife" if str(npc.gender).to_lower() == "female" else "spouse"

	for raw_parent_id in player.parents:
		var parent: Person = gs.get_npc_by_id(int(raw_parent_id))
		if parent == null:
			continue

		if npc_id in parent.parents:
			return "grandfather" if str(npc.gender).to_lower() == "male" else "grandmother" if str(npc.gender).to_lower() == "female" else "grandparent"

		if npc_id in parent.children and npc_id != int(player.id):
			return "brother" if str(npc.gender).to_lower() == "male" else "sister" if str(npc.gender).to_lower() == "female" else "sibling"

	return ""





func maybe_quit_or_switch(npc):
	if npc == null:
		return
	if npc.job == "":
		return

	if npc.satisfaction < 20 and randi() % 100 < 10:
		var old_job = npc.job

		if gs.workplace_engine != null:
			gs.workplace_engine.unregister_worker(npc)

		gs.narrative_engine.log_event(npc, {
			"type": "job_quit",
			"job": npc.job
		})

		npc.job = ""
		npc.income = 0
		npc.current_workplace_id = ""
		npc.coworkers.clear()

		if gs.event_bus != null:
			gs.event_bus.emit(ActionEventTypes.JOB_QUIT, {
				"npc_id": npc.id,
				"text": "%s quit working as a %s." % [npc.first_name, old_job],
				"job_name": old_job
			})