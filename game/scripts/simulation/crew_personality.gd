extends Node
class_name CrewPersonality

## Modular crew personality with trait-driven behavior.
## Traits are composable modifiers that affect combat, exploration, and social outcomes.

var crew_id: String = ""
var role: String = ""  # pilot, engineer, scientist, security, medic, diplomat
var name: String = ""
var traits: PackedStringArray = PackedStringArray()
var stress: int = 0
var morale: int = 100
var health: int = 100
var relationship_matrix: Dictionary = {}  # crew_id -> affinity [-100, 100]


func _init(p_crew_id: String, p_role: String, p_name: String) -> void:
	crew_id = p_crew_id
	role = p_role
	name = p_name


func add_trait(trait_id: String) -> void:
	if trait_id not in traits:
		traits.append(trait_id)


func get_trait_modifiers(traits_contract: Dictionary) -> Dictionary:
	## Resolve all trait modifiers into a unified effect dictionary.
	var trait_list = traits_contract.get("traits", [])
	var modifiers: Dictionary = {}
	
	for trait_id in traits:
		for trait in trait_list:
			if trait.get("id") == trait_id:
				var effects = trait.get("modifiers", [])
				for effect in effects:
					var target = effect.get("target", "")
					var operation = effect.get("operation", "add")
					var value = effect.get("value", 0)
					
					if operation == "add":
						modifiers[target] = modifiers.get(target, 0.0) + value
					elif operation == "multiply":
						if target not in modifiers:
							modifiers[target] = 1.0
						modifiers[target] *= value
				break
	
	return modifiers


func apply_stress(amount: int) -> void:
	stress = min(100, stress + amount)
	if stress > 75:
		# High stress triggers panic risk in combat
		pass


func recover_stress(amount: int) -> void:
	stress = max(0, stress - amount)


func is_panicked() -> bool:
	return stress > 75


func modify_affinity(other_crew_id: String, delta: int) -> void:
	var current: int = relationship_matrix.get(other_crew_id, 0)
	relationship_matrix[other_crew_id] = clamp(current + delta, -100, 100)


func get_affinity(other_crew_id: String) -> int:
	return relationship_matrix.get(other_crew_id, 0)


func serialize() -> Dictionary:
	return {
		"crew_id": crew_id,
		"role": role,
		"name": name,
		"traits": traits,
		"stress": stress,
		"morale": morale,
		"health": health,
		"relationship_matrix": relationship_matrix
	}


func deserialize(data: Dictionary) -> void:
	crew_id = data.get("crew_id", "")
	role = data.get("role", "")
	name = data.get("name", "")
	traits = data.get("traits", PackedStringArray())
	stress = data.get("stress", 0)
	morale = data.get("morale", 100)
	health = data.get("health", 100)
	relationship_matrix = data.get("relationship_matrix", {})
