extends Node
class_name GameState

## Persistent game state for a single run.
## Serializable for save/load.

var run_seed: int = 0
var current_destination: String = "earth"
var visited_destinations: PackedStringArray = PackedStringArray()
var crew: Array = []
var flags: Dictionary = {}
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
		"resources": resources
	}


func deserialize(data: Dictionary) -> void:
	run_seed = data.get("run_seed", 0)
	current_destination = data.get("current_destination", "earth")
	visited_destinations = data.get("visited_destinations", PackedStringArray())
	crew = data.get("crew", [])
	flags = data.get("flags", {})
	resources = data.get("resources", {})
