extends Node
class_name GameSaveManager

## Handles game state serialization and save/load operations.

const SAVE_DIR: String = "user://saves/"
const SAVE_VERSION: int = 1


func _ready() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_abs_absolute(SAVE_DIR)


func save_game(game_state: GameState, crew: Array, filename: String = "autosave") -> bool:
	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_ticks_msec(),
		"game_state": game_state.serialize(),
		"crew": serialize_crew(crew)
	}
	
	var file_path: String = SAVE_DIR + filename + ".tilly"
	var json_string: String = JSON.stringify(save_data)
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		print("Error saving game: %s" % error_string(FileAccess.get_open_error()))
		return false
	
	file.store_string(json_string)
	print("Game saved to %s" % file_path)
	return true


func load_game(filename: String = "autosave") -> Dictionary:
	var file_path: String = SAVE_DIR + filename + ".tilly"
	
	if not FileAccess.file_exists(file_path):
		print("Save file not found: %s" % file_path)
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		print("Error loading game: %s" % error_string(FileAccess.get_open_error()))
		return {}
	
	var json_string: String = file.get_as_text()
	var json = JSON.parse_string(json_string)
	
	if json == null:
		print("Error parsing save file")
		return {}
	
	print("Game loaded from %s" % file_path)
	return json


func list_saves() -> Array:
	var saves: Array = []
	var dir = DirAccess.open(SAVE_DIR)
	
	if dir:
		dir.list_dir_begin()
		var filename: String = dir.get_next()
		while filename != "":
			if filename.ends_with(".tilly"):
				saves.append(filename.trim_suffix(".tilly"))
			filename = dir.get_next()
	
	return saves


func serialize_crew(crew: Array) -> Array:
	var serialized: Array = []
	for crew_member in crew:
		serialized.append(crew_member.serialize())
	return serialized


func deserialize_crew(crew_data: Array, traits_contract: Dictionary) -> Array:
	var crew: Array = []
	for member_data in crew_data:
		var personality = CrewPersonality.new()
		personality.deserialize(member_data, traits_contract)
		crew.append(personality)
	return crew
