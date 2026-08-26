extends Resource
class_name PlayableLifeViewer

const VIEWER_SCHEMA:= "eralife.playable_life_viewer"
const LIFE_SHELL_SCHEMA:= "eralife.playable_life_shell"
const RENDER_PACKET_SCHEMA:= "eralife.playable_life_viewer.render_packet"
const CONTRACT_VERSION:= 1

var mounted_actor_id: int = -1
var mounted_signature: String = ""
var mounted_shell: Dictionary = {}
var mounted_packet: Dictionary = {}


func mount(life_shell: Dictionary, context: Dictionary = {}) -> Dictionary:
	return bind(life_shell, context)


func bind(life_shell: Dictionary, context: Dictionary = {}) -> Dictionary:
	var shell: Dictionary = normalize_life_shell(life_shell)
	if not can_bind_zero_frame(shell):
		return {
			"success": false,
			"reason": "life_shell_not_zero_frame_ready",
			"schema": VIEWER_SCHEMA,
			"version": CONTRACT_VERSION,
			"life_shell": shell.duplicate(true),
			"context": context.duplicate(true)
		}

	var packet: Dictionary = render_packet_for_shell(shell, context)

	mounted_actor_id = int(shell.get("actor_id", -1))
	mounted_signature = str(shell.get("life_diary_signature", shell.get("signature", ""))).strip_edges()
	mounted_shell = shell.duplicate(true)
	mounted_packet = packet.duplicate(true)

	return {
		"success": true,
		"mode": "playable_life_viewer_bound",
		"schema": VIEWER_SCHEMA,
		"version": CONTRACT_VERSION,
		"actor_id": mounted_actor_id,
		"actor_name": str(shell.get("actor_name", "Unknown Life")).strip_edges(),
		"signature": mounted_signature,
		"render_packet": packet.duplicate(true),
		"viewer_policy": _viewer_policy(),
		"context": context.duplicate(true)
	}


func can_bind_zero_frame(life_shell: Dictionary) -> bool:
	var shell: Dictionary = normalize_life_shell(life_shell)
	if shell.is_empty():
		return false
	if int(shell.get("actor_id", -1)) <= 0:
		return false
	if _safe_dictionary(shell.get("surface_contract", {})).is_empty():
		return false
	if not bool(shell.get("playable_life_shell_ready", false)):
		return false
	if not bool(shell.get("switch_press_only_commits_pointer", false)):
		return false
	if bool(shell.get("viewer_may_wait", true)):
		return false
	if bool(shell.get("viewer_may_call_simulation", true)):
		return false
	if bool(shell.get("viewer_may_mutate_state", true)):
		return false
	if bool(shell.get("viewer_may_fetch", true)):
		return false
	if bool(shell.get("viewer_may_rebuild_layout", true)):
		return false
	return true


func render_packet_for_shell(life_shell: Dictionary, context: Dictionary = {}) -> Dictionary:
	var shell: Dictionary = normalize_life_shell(life_shell)
	var surface: Dictionary = _safe_dictionary(shell.get("surface_contract", {}))
	var actor_id: int = int(shell.get("actor_id", surface.get("actor_id", -1)))
	var actor_name: String = str(shell.get("actor_name", surface.get("actor_name", "Unknown Life"))).strip_edges()
	if actor_name == "":
		actor_name = "Unknown Life"

	surface ["actor_id"] = actor_id
	surface ["actor_name"] = actor_name
	surface ["current_panel"] = str(surface.get("current_panel", "life")).strip_edges()
	if surface ["current_panel"] == "":
		surface ["current_panel"] = "life"

	var life_lines: Array = _safe_array(shell.get("life_diary_lines", surface.get("life_diary_lines", [])))
	var life_entries: Array = _safe_array(shell.get("life_diary_entries", surface.get("life_diary_entries", [])))
	var hud_truth: Dictionary = _safe_dictionary(surface.get("hud_truth", shell.get("hud_truth", {})))
	var surface_context: Dictionary = _safe_dictionary(surface.get("player_stats_surface_context", surface.get("surface_context", shell.get("surface_context", {}))))

	surface ["life_diary_lines"] = life_lines.duplicate(true)
	surface ["life_diary_entries"] = life_entries.duplicate(true)
	surface ["hud_truth"] = hud_truth.duplicate(true)
	surface ["player_stats_surface_context"] = surface_context.duplicate(true)
	surface ["surface_context"] = surface_context.duplicate(true)
	surface ["prewarmed_playable_life_shell"] = true
	surface ["runtime_hud_shell_prewarmed"] = bool(shell.get("runtime_hud_shell_prewarmed", surface.get("runtime_hud_shell_prewarmed", false)))
	surface ["switch_press_must_not_build_surface"] = true
	surface ["viewer_interpreted"] = true
	surface ["playable_life_viewer_schema"] = RENDER_PACKET_SCHEMA

	return {
		"schema": RENDER_PACKET_SCHEMA,
		"version": CONTRACT_VERSION,
		"actor_id": actor_id,
		"actor_name": actor_name,
		"signature": str(shell.get("life_diary_signature", shell.get("signature", ""))).strip_edges(),
		"current_panel": str(surface.get("current_panel", "life")),
		"surface_contract": surface.duplicate(true),
		"player_stats_packet": _player_stats_packet(surface, surface_context),
		"life_diary_packet": _life_diary_packet(surface, life_lines, life_entries),
		"hud_packet": _hud_packet(surface, hud_truth),
		"nav_packet": _nav_packet(surface),
		"render_policy": _viewer_policy(),
		"context": context.duplicate(true)
	}


func normalize_life_shell(life_shell: Dictionary) -> Dictionary:
	if typeof(life_shell) != TYPE_DICTIONARY:
		return {}

	var shell: Dictionary = life_shell.duplicate(true)
	var surface: Dictionary = _safe_dictionary(shell.get("surface_contract", shell.get("surface", {})))
	if surface.is_empty():
		return shell

	var actor_id: int = int(shell.get("actor_id", surface.get("actor_id", -1)))
	var actor_name: String = str(shell.get("actor_name", surface.get("actor_name", "Unknown Life"))).strip_edges()
	if actor_name == "":
		actor_name = "Unknown Life"

	shell ["schema"] = str(shell.get("schema", LIFE_SHELL_SCHEMA))
	shell ["version"] = int(shell.get("version", CONTRACT_VERSION))
	shell ["actor_id"] = actor_id
	shell ["actor_name"] = actor_name
	shell ["surface_contract"] = surface.duplicate(true)



	shell ["playable_life_shell_ready"] = bool(shell.get("playable_life_shell_ready", false))
	shell ["switch_press_only_commits_pointer"] = bool(shell.get("switch_press_only_commits_pointer", true))



	shell ["viewer_may_wait"] = false
	shell ["viewer_may_call_simulation"] = false
	shell ["viewer_may_mutate_state"] = false
	shell ["viewer_may_fetch"] = false
	shell ["viewer_may_rebuild_layout"] = false

	return shell
func mounted_render_packet() -> Dictionary:
	return mounted_packet.duplicate(true)


func mounted_life_shell() -> Dictionary:
	return mounted_shell.duplicate(true)


func mounted_actor() -> int:
	return mounted_actor_id


func _player_stats_packet(surface: Dictionary, surface_context: Dictionary) -> Dictionary:
	var stats: Dictionary = _safe_dictionary(surface.get("stats", {}))

	return {
		"actor_id": int(surface.get("actor_id", -1)),
		"actor_name": str(surface.get("actor_name", "Unknown Life")).strip_edges(),
		"bank_balance": max(0, int(surface.get("bank_balance", surface.get("money", 0)))),
		"health": max(0, int(surface.get("health", stats.get("health", 0)))),
		"hunger": max(0, int(surface.get("hunger", stats.get("hunger", 0)))),
		"mental_health": max(0, int(surface.get("mental_health", stats.get("mental_health", stats.get("mental", 0))))),
		"mental": max(0, int(surface.get("mental", surface.get("mental_health", stats.get("mental", 0))))),
		"willpower": max(0, int(surface.get("willpower", stats.get("willpower", 0)))),
		"happiness": max(0, int(surface.get("happiness", stats.get("happiness", 0)))),
		"smarts": max(0, int(surface.get("smarts", stats.get("smarts", 0)))),
		"looks": max(0, int(surface.get("looks", stats.get("looks", 0)))),
		"imagination": max(0, int(surface.get("imagination", stats.get("imagination", 0)))),
		"fame": max(0, int(surface.get("fame", stats.get("fame", 0)))),
		"approval": clampi(int(surface.get("approval", stats.get("approval", 0))), 0, 100),
		"surface_context": surface_context.duplicate(true),
	}


func _life_diary_packet(surface: Dictionary, life_lines: Array, life_entries: Array) -> Dictionary:
	var text_block: String = _life_diary_text_for_lines(life_lines)

	return {
		"actor_id": int(surface.get("actor_id", -1)),
		"actor_name": str(surface.get("actor_name", "Unknown Life")).strip_edges(),
		"lines": life_lines.duplicate(true),
		"entries": life_entries.duplicate(true),
		"signature": str(surface.get("life_diary_signature", "")).strip_edges(),
		"text": text_block,
		"bbcode_text": text_block,
	}
func _life_diary_text_for_lines(life_lines: Array) -> String:
	if typeof(life_lines) != TYPE_ARRAY or life_lines.is_empty():
		return ""

	var parts: Array [String] = []
	for raw_line in life_lines:
		var line_text: String = str(raw_line).strip_edges()
		if line_text == "":
			continue
		parts.append(line_text)

	return "\n".join(parts)

func _hud_packet(surface: Dictionary, hud_truth: Dictionary) -> Dictionary:
	return {
		"actor_id": int(surface.get("actor_id", -1)),
		"actor_name": str(surface.get("actor_name", "Unknown Life")).strip_edges(),
		"hud_truth": hud_truth.duplicate(true),
		"belongings_available": bool(hud_truth.get("belongings_available", hud_truth.get("belongings", true))),
		"bending_available": bool(hud_truth.get("bending_available", hud_truth.get("bending", false))),
		"crown_available": bool(hud_truth.get("crown_available", hud_truth.get("crown", false))),
		"food_lifestyle_available": bool(hud_truth.get("food_lifestyle_available", hud_truth.get("grocery_store_available", false))),
		"restaurant_lifestyle_available": bool(hud_truth.get("restaurant_lifestyle_available", hud_truth.get("restaurant_available", false))),
		"rick_weapon_shop_available": bool(hud_truth.get("rick_weapon_shop_available", false)),
		"boxing_available": bool(hud_truth.get("boxing_available", hud_truth.get("boxing", false))),
		"superhero_available": bool(hud_truth.get("superhero_available", hud_truth.get("superhero", false))),
		"superpower_available": bool(hud_truth.get("superpower_available", hud_truth.get("superpower", hud_truth.get("superhero_available", false)))),
		"power_available": bool(hud_truth.get("power_available", hud_truth.get("power", false))),
		"wizard_available": bool(hud_truth.get("wizard_available", hud_truth.get("wizard", false))),
		"runtime_hud_shell_prewarmed": bool(surface.get("runtime_hud_shell_prewarmed", false)),
	}


func _nav_packet(surface: Dictionary) -> Dictionary:
	return {
		"current_panel": str(surface.get("current_panel", "life")).strip_edges(),
		"layout_rebuild_forbidden": true,
	}


func _viewer_policy() -> Dictionary:
	return {
		"viewer_calls_simulation": false,
		"viewer_mutates_simulation_state": false,
		"viewer_fetches_data": false,
		"viewer_waits": false,
		"viewer_rebuilds_layout": false,
		"render_immediately": true,
		"blank_frame_forbidden": true,
		"stat_reset_flicker_forbidden": true,
		"hud_mismatch_forbidden": true,
		"loading_forbidden": true,
		"press_only_commits_pointer": true,
	}


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return []