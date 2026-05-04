extends Node
class_name CrewGenerator

## Procedurally generate crew members with random traits and personalities.

var rng: TillyRNG


func _init(p_rng: TillyRNG) -> void:
	rng = p_rng


func generate_crew(count: int, archetypes_contract: Dictionary, traits_contract: Dictionary) -> Array:
	var crew: Array = []
	var archetype_list = archetypes_contract.get("archetypes", [])
	
	for i in range(count):
		var archetype = archetype_list[rng.next_int(0, archetype_list.size())]
		var crew_member = generate_crew_member(archetype, traits_contract)
		crew.append(crew_member)
	
	# Initialize relationship matrix between all crew members
	for i in range(crew.size()):
		for j in range(crew.size()):
			if i != j:
				crew[i].relationship_matrix[crew[j].crew_id] = rng.next_int(-20, 20)
	
	return crew


func generate_crew_member(archetype: Dictionary, traits_contract: Dictionary) -> CrewPersonality:
	var role = archetype.get("role", "security")
	var crew_id = "%s_%d" % [role, rng.next_int(1000, 9999)]
	var name = generate_name()
	
	var member = CrewPersonality.new(crew_id, role, name)
	
	# Add traits from archetype pool
	var trait_pool = archetype.get("trait_pool", [])
	for trait_id in trait_pool:
		if rng.next_float() < 0.6:  # 60% chance to get each trait
			member.add_trait(trait_id)
	
	return member


func generate_name() -> String:
	var first_names = ["Alex", "Jordan", "Casey", "Morgan", "Riley", "Taylor", "Dakota", "Skylar", "Quinn", "Avery"]
	var last_names = ["Chen", "Smith", "Okafor", "Kowalski", "Martinez", "Patel", "Johnson", "Anderson", "Lee", "Reeves"]
	
	var first = first_names[rng.next_int(0, first_names.size())]
	var last = last_names[rng.next_int(0, last_names.size())]
	
	return "%s %s" % [first, last]
