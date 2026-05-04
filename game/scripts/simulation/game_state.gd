extends Node
class_name GameState

## Persistent game state for a single run.
## Serializable for save/load.

var run_seed: int = 0
var current_destination: String = "earth"
var visited_destinations: PackedStringArray = PackedStringArray()
var crew: Array = []
var flags: Dictionary = {}
var turn_number: int = 0          # Increments on each destination arrival
var run_result: String = "ongoing" # "ongoing" | "victory" | "defeat" | "stranded"
var resources: Dictionary = {
	"fuel": 100,
	"scrap": 0,
	"morale": 100,
	"hull_integrity": 100,
	"power_available": 10
}


func _init(seed_value: int = 0) -> void:
	run_seed = seed_value
	visited_destinations.append("earth")


func set_destination(dest_id: String) -> void:
	current_destination = dest_id
	if dest_id not in visited_destinations:
		visited_destinations.append(dest_id)


func increment_turn() -> int:
	turn_number += 1
	return turn_number


func check_game_over() -> String:
	## Evaluates all game-over conditions. Returns run_result string.
	## Callers should act on a non-"ongoing" result.
	
	if run_result != "ongoing":
		return run_result  # Already settled
	
	# Defeat: ship hull at zero
	if resources.get("hull_integrity", 100) <= 0:
		run_result = "defeat"
		return run_result
	
	# Defeat: all crew dead
	if has_flag("all_crew_dead"):
		run_result = "defeat"
		return run_result
	
	# Stranded: out of fuel and not at a safe port
	var safe_ports: Array = ["earth", "mars_colony"]
	if resources.get("fuel", 100) <= 0 and current_destination not in safe_ports:
		run_result = "stranded"
		return run_result
	
	# Victory: visited all 8 destinations
	if visited_destinations.size() >= 8:
		run_result = "victory"
		return run_result
	
	# Victory: reached Pluto (the deep-system objective)
	if "pluto" in visited_destinations:
		run_result = "victory"
		return run_result
	
	return "ongoing"


func add_flag(flag_name: String, value: bool = true) -> void:
	flags[flag_name] = value


func has_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)


func modify_resource(resource_name: String, delta: int) -> void:
	if resource_name in resources:
		resources[resource_name] = max(0, resources[resource_name] + delta)


func get_resource(resource_name: String) -> int:
	return resources.get(resource_name, 0)


func serialize() -> Dictionary:
	return {
		"run_seed": run_seed,
		"current_destination": current_destination,
		"visited_destinations": visited_destinations,
		"crew": crew,
		"flags": flags,
		"resources": resources,
		"turn_number": turn_number,
		"run_result": run_result
	}


func deserialize(data: Dictionary) -> void:
	run_seed = data.get("run_seed", 0)
	current_destination = data.get("current_destination", "earth")
	visited_destinations = data.get("visited_destinations", PackedStringArray())
	crew = data.get("crew", [])
	flags = data.get("flags", {})
	resources = data.get("resources", {})
	turn_number = data.get("turn_number", 0)
	run_result = data.get("run_result", "ongoing")
