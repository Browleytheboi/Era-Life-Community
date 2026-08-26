extends Resource
class_name WeaponPackLoader

var gs

func _init(_gs):
	gs = _gs

func load_weapon_packs():

	var dir = DirAccess.open("res://data/weapons")
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".json"):

			var path = "res://data/weapons/" + file_name
			var f = FileAccess.open(path, FileAccess.READ)
			var parsed = JSON.parse_string(f.get_as_text())
			f.close()

			if typeof(parsed) == TYPE_DICTIONARY:

				var era_name = parsed.get("era_name", "")
				var weapons = parsed.get("weapons", [])

				if era_name != "":
					gs.weapons_engine.WEAPON_STORES [era_name] = weapons

		file_name = dir.get_next()

	dir.list_dir_end()