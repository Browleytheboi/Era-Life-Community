extends Resource
class_name EventEngine

var gs
func _init(_gs):
	gs = _gs

func generate_year_events(person):
	var events = []
	if person == null:
		return events

	if gs.school_engine != null:
		var is_school_visible = gs.school_engine._is_school_visible_age(person)
		var is_active_student = gs.school_engine._is_active_student(person)
		var classmates = gs.school_engine.get_classmates(person)

		if is_school_visible and gs.school_engine.can_attend_school(person) and is_active_student:
			events.append({
				"type": "text",
				"text": "Another school year passed.",
				"player_text": "Another school year passed.",
				"source": "event_engine",
				"category": "school",
				"diary_scope": "player"
			})

		if person.age >= 13 and is_active_student and classmates.size() > 0:
			events.append({
				"type": "text",
				"text": "A classmate had a crush on you.",
				"player_text": "A classmate had a crush on you.",
				"source": "event_engine",
				"category": "school",
				"diary_scope": "player"
			})

	if gs.property_engine != null:
		for evt in gs.property_engine.get_yearly_event_fragments_for_owner(person):
			if typeof(evt) == TYPE_DICTIONARY:
				evt ["source"] = str(evt.get("source", "property_engine"))
				evt ["diary_scope"] = str(evt.get("diary_scope", "player"))
			events.append(evt)

	if gs.vehicle_engine != null:
		for evt in gs.vehicle_engine.get_yearly_event_fragments_for_owner(person):
			if typeof(evt) == TYPE_DICTIONARY:
				evt ["source"] = str(evt.get("source", "vehicle_engine"))
				evt ["diary_scope"] = str(evt.get("diary_scope", "player"))
			events.append(evt)

	return events