extends Node
class_name ContractLoader

## Loads and validates all game content contracts at startup.
## Enforces schema compliance and reference integrity.

var contracts: Dictionary = {}
var validation_errors: PackedStringArray = PackedStringArray()


func _init() -> void:
	pass


func load_all() -> bool:
	var errors: PackedStringArray = PackedStringArray()
	
	# Load each contract file
	var crew_traits_ok: bool = load_contract("crew_traits", "res://data/crew_traits.json")
	if not crew_traits_ok:
		errors.append("Failed to load crew_traits contract")
	
	var crew_archetypes_ok: bool = load_contract("crew_archetypes", "res://data/crew_archetypes.json")
	if not crew_archetypes_ok:
		errors.append("Failed to load crew_archetypes contract")
	
	var destinations_ok: bool = load_contract("destinations", "res://data/destinations.json")
	if not destinations_ok:
		errors.append("Failed to load destinations contract")
	
	var events_ok: bool = load_contract("events", "res://data/events.json")
	if not events_ok:
		errors.append("Failed to load events contract")
	
	var enemies_ok: bool = load_contract("enemy_templates", "res://data/enemy_templates.json")
	if not enemies_ok:
		errors.append("Failed to load enemy_templates contract")
	
	var ship_modules_ok: bool = load_contract("ship_modules", "res://data/ship_modules.json")
	if not ship_modules_ok:
		errors.append("Failed to load ship_modules contract")
	
	if errors.size() > 0:
		validation_errors = errors
		return false
	
	# Perform cross-reference validation
	if not validate_references():
		return false
	
	return true


func load_contract(name: String, path: String) -> bool:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		validation_errors.append("Cannot open file: %s" % path)
		return false
	
	var json = JSON.new()
	var error: Error = json.parse(file.get_as_text())
	if error != OK:
		validation_errors.append("JSON parse error in %s: %s" % [path, json.get_error_message()])
		return false
	
	var data = json.data
	if data == null:
		validation_errors.append("Empty or invalid JSON in %s" % path)
		return false
	
	contracts[name] = data
	return true


func validate_references() -> bool:
	var errors: PackedStringArray = PackedStringArray()
	
	# Build trait ID set
	var trait_ids: HashSet = HashSet()
	if "crew_traits" in contracts:
		var traits = contracts["crew_traits"].get("traits", [])
		for trait in traits:
			trait_ids.add(trait.get("id", ""))
	
	# Validate archetype trait references
	if "crew_archetypes" in contracts:
		var archetypes = contracts["crew_archetypes"].get("archetypes", [])
		for archetype in archetypes:
			var trait_pool = archetype.get("trait_pool", [])
			for trait_id in trait_pool:
				if not trait_ids.has(trait_id):
					errors.append("Archetype '%s' references unknown trait '%s'" % [archetype.get("id"), trait_id])
	
	# Build destination ID set
	var dest_ids: HashSet = HashSet()
	if "destinations" in contracts:
		var destinations = contracts["destinations"].get("destinations", [])
		for dest in destinations:
			dest_ids.add(dest.get("id", ""))
	
	# Validate destination neighbor references
	if "destinations" in contracts:
		var destinations = contracts["destinations"].get("destinations", [])
		for dest in destinations:
			var neighbors = dest.get("neighbors", [])
			for neighbor_id in neighbors:
				if not dest_ids.has(neighbor_id):
					errors.append("Destination '%s' references unknown neighbor '%s'" % [dest.get("id"), neighbor_id])
	
	if errors.size() > 0:
		validation_errors.append_array(errors)
		return false
	
	return true


func get_contract(name: String) -> Dictionary:
	return contracts.get(name, {})


func has_errors() -> bool:
	return validation_errors.size() > 0


func print_errors() -> void:
	for error in validation_errors:
		print("VALIDATION ERROR: " + error)


class HashSet:
	var _dict: Dictionary = {}
	
	func add(value) -> void:
		_dict[value] = true
	
	func has(value) -> bool:
		return value in _dict
