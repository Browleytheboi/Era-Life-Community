extends Resource
class_name ChooseAdventureEngine

const CONTRACT_SCHEMA:= "eralife.choose_adventure_engine"
const CONTRACT_VERSION:= 1

var gs
var last_report: Dictionary = {}


func _init(_gs = null):
	gs = _gs
	_ensure_runtime()


func _ensure_runtime() -> void:
	if gs == null:
		return
	if gs.narrative_governor == null:
		gs.narrative_governor = NarrativeGovernor.new(gs)
	if gs.lineage_engine == null:
		gs.lineage_engine = LineageEngine.new(gs)
	if gs.choose_adventure_ai_node_generator == null:
		gs.choose_adventure_ai_node_generator = ChooseAdventureAINodeGenerator.new(gs)
	if gs.choose_adventure_scenario_engine == null:
		gs.choose_adventure_scenario_engine = ChooseAdventureScenarioEngine.new(gs)


func build_entry_surface_contract() -> Dictionary:
	return {
		"schema": "eralife.choose_adventure_entry_surface",
		"version": CONTRACT_VERSION,
		"id": "default_choose_adventure_entry_surface",
		"title": "Choose your own Adventure",
		"layout": {
			"type": "triple_entry",
			"animated": true,
			"divider": "three_lanes"
		},
		"panels": [
			{
				"id": "choose_adventure",
				"eyebrow": "NARRATIVE MODE",
				"title": "Choose your own Adventure",
				"subtitle": "Choose a story and make choices before birth. Every choice forces pressure into the simulation until the story becomes a life.",
				"button_text": "Begin Adventure",
				"footer": "Choice → pressure → world reaction → dynamic outcome.",
				"accent": Color(0.82, 0.42, 1.0),
				"min_width": 352,
				"min_height": 620,
				"button_role": "narrative_alive",
				"button_motion": {
					"pulse": "heartbeat",
					"speed": 0.72,
					"scale": 1.045,
					"text_glow": true
				}
			},
			{
				"id": "choose_household",
				"eyebrow": "HOUSEHOLD MODE",
				"title": "🏡Choose your own Household",
				"subtitle": "Build a text-based dollhouse: select the world, prewarm the seed, create household members progressively, then choose whose life you enter.",
				"button_text": "Create Household",
				"footer": "Full Family control",
				"accent": Color(1.0, 0.18, 0.06),
				"min_width": 392,
				"min_height": 620,
				"button_role": "household_alive",
				"button_motion": {
					"pulse": "fire_breathe",
					"speed": 0.58,
					"scale": 1.058,
					"text_glow": true
				}
			},
			{
				"id": "choose_ereality",
				"eyebrow": "GOD MODE",
				"title": "Choose Your Ereality",
				"subtitle": "Skip the narrative threshold and open the existing God Mode panel to shape the life manually.",
				"button_text": "Open God mode",
				"footer": "Direct creation. Same Ereality. Different doorway.",
				"accent": Color(0.24, 0.86, 1.0),
				"min_width": 352,
				"min_height": 620,
				"button_role": "god_mode_alive",
				"button_motion": {
					"pulse": "cosmic_breathe",
					"speed": 1.25,
					"scale": 1.025,
					"text_glow": true
				}
			}
		],
		"metadata": {
			"surface_owner": CONTRACT_SCHEMA,
		}
	}

func start_adventure(story_id: String = "") -> Dictionary:
	_ensure_runtime()

	if gs == null or gs.choose_adventure_scenario_engine == null:
		return _error_result("Choose Adventure scenario engine is unavailable.")

	var clean_story_id: String = str(story_id).strip_edges()
	var result: Dictionary = {}

	if clean_story_id == "":
		result = gs.choose_adventure_scenario_engine.build_adventure_catalog_result()
	else:
		result = gs.choose_adventure_scenario_engine.start_story(clean_story_id)

	last_report = {
		"schema": "eralife.choose_adventure_start_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"story_id": clean_story_id,
		"result_type": str(result.get("type", "")),
		"started_at_ms": int(Time.get_ticks_msec())
	}
	return result


func choose(choice_id: String) -> Dictionary:
	_ensure_runtime()

	if gs == null or gs.choose_adventure_scenario_engine == null:
		return _error_result("Choose Adventure scenario engine is unavailable.")

	var result: Dictionary = gs.choose_adventure_scenario_engine.choose(choice_id)
	last_report = {
		"schema": "eralife.choose_adventure_choice_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"choice_id": choice_id,
		"result_type": str(result.get("type", "")),
		"resolved_at_ms": int(Time.get_ticks_msec())
	}
	return result


func export_state() -> Dictionary:
	_ensure_runtime()

	if gs == null or gs.choose_adventure_scenario_engine == null:
		return {
			"schema": "eralife.choose_adventure_state",
			"version": CONTRACT_VERSION,
			"data": {}
		}

	return gs.choose_adventure_scenario_engine.export_state()


func import_state(data: Dictionary) -> Dictionary:
	_ensure_runtime()

	if gs == null or gs.choose_adventure_scenario_engine == null:
		return {
			"success": false,
			"reason": "Choose Adventure scenario engine is unavailable."
		}

	return gs.choose_adventure_scenario_engine.import_state(data)


func _error_result(message: String) -> Dictionary:
	return {
		"type": "choose_adventure_error",
		"panel_title": "Choose Your Own Adventure",
		"subtitle": "Route unavailable",
		"text": message,
		"opps": [],
		"footer_text": "The contract-driven adventure route could not start."
	}