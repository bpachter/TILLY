extends Node
class_name EventResolver

## Evaluates and executes event outcomes based on conditions and game state.
## Works directly with event contract payloads.

var game_state: GameState
var rng: TillyRNG


func _init(p_game_state: GameState, p_rng: TillyRNG) -> void:
	game_state = p_game_state
	rng = p_rng


func resolve_event(event_data: Dictionary) -> Dictionary:
	var event_id: String = event_data.get("id", "")
	var conditions: Array = event_data.get("conditions", [])
	var choices: Array = event_data.get("choices", [])
	
	# Check event conditions
	if not evaluate_conditions(conditions):
		return {"triggered": false}
	
	# Trigger event and present choices
	return {
		"triggered": true,
		"event_id": event_id,
		"title": event_data.get("title", ""),
		"choices": choices
	}


func evaluate_conditions(conditions: Array) -> bool:
	if conditions.is_empty():
		return true
	
	for condition in conditions:
		if not evaluate_condition(condition):
			return false
	
	return true


func evaluate_condition(condition: Dictionary) -> bool:
	var key: String = condition.get("key", "")
	var operator: String = condition.get("operator", "eq")
	var expected_value = condition.get("value")
	
	var actual_value = get_condition_value(key)
	
	match operator:
		"eq":
			return actual_value == expected_value
		"neq":
			return actual_value != expected_value
		"gt":
			return actual_value > expected_value
		"gte":
			return actual_value >= expected_value
		"lt":
			return actual_value < expected_value
		"lte":
			return actual_value <= expected_value
		"contains":
			if actual_value is Array:
				return expected_value in actual_value
			if actual_value is String:
				return expected_value in actual_value
			return false
		_:
			return false


func get_condition_value(key: String):
	if key.begins_with("flag:"):
		var flag_name: String = key.substr(5)
		return game_state.has_flag(flag_name)
	
	if key.begins_with("resource:"):
		var resource_name: String = key.substr(9)
		return game_state.get_resource(resource_name)
	
	match key:
		"current_destination":
			return game_state.current_destination
		"destination_count":
			return game_state.visited_destinations.size()
		"crew_size":
			return game_state.crew.size()
		_:
			return null


func apply_choice(choice_data: Dictionary) -> void:
	var effects: Array = choice_data.get("effects", [])
	
	for effect in effects:
		apply_effect(effect)


func apply_effect(effect: Dictionary) -> void:
	var target: String = effect.get("target", "")
	var operation: String = effect.get("operation", "set")
	var value = effect.get("value")
	
	if target.begins_with("flag:"):
		var flag_name: String = target.substr(5)
		game_state.add_flag(flag_name, value if value is bool else true)
		return
	
	if target.begins_with("resource:"):
		var resource_name: String = target.substr(9)
		if operation == "add":
			game_state.modify_resource(resource_name, int(value))
		else:
			game_state.resources[resource_name] = value
		return
