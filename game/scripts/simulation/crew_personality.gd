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

# --- Ambition system ---
# Each crew member has one hidden personal goal that advances via destinations/events.
# ambition_id: String key (e.g. "visit_titan", "discover_alien_life")
# ambition_progress: 0-100
# ambition_complete: true when first filled
var ambition_id: String = ""
var ambition_label: String = ""          # Human-readable goal description
var ambition_progress: int = 0
var ambition_complete: bool = false
var ambition_trigger_destinations: Array = []  # Destination IDs that advance this ambition
var ambition_trigger_events: Array = []        # Event IDs that advance this ambition

# --- Mental health / phobia system ---
# Phobias acquired when stress > PHOBIA_THRESHOLD for sustained periods.
# They create event-specific penalties and can be resolved through therapy events.
# phobias: Array of String phobia IDs currently active
# phobia_exposure_count: Dictionary phobia_id -> consecutive stressed periods
var phobias: Array = []
var phobia_exposure_count: Dictionary = {}

# Skill progression: role-specific XP accumulated through combat/events
# skill_xp: Dictionary role_skill -> int (e.g. {"navigation": 40, "repair": 15})
# Each role has one primary skill that naturally accumulates.
var skill_xp: Dictionary = {}
var skill_level: Dictionary = {}  # role_skill -> 0, 1, 2 (novice, proficient, expert)


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


func is_dead() -> bool:
	return health <= 0


func apply_health_damage(amount: int) -> bool:
	## Apply combat injury. Returns true if this damage caused death.
	var was_alive: bool = health > 0
	health = max(0, health - amount)
	return was_alive and health <= 0


# ---- Ambition methods ----

func set_ambition(p_ambition_id: String, p_label: String, p_destinations: Array, p_events: Array) -> void:
	ambition_id = p_ambition_id
	ambition_label = p_label
	ambition_trigger_destinations = p_destinations
	ambition_trigger_events = p_events
	ambition_progress = 0
	ambition_complete = false


func advance_ambition_by_destination(dest_id: String) -> int:
	## Call when arriving at a new destination. Returns XP gained (0 if none).
	if ambition_complete or dest_id not in ambition_trigger_destinations:
		return 0
	var gain: int = 25
	ambition_progress = min(100, ambition_progress + gain)
	if ambition_progress >= 100:
		ambition_complete = true
	return gain


func advance_ambition_by_event(event_id: String) -> int:
	## Call when an event is triggered. Returns XP gained (0 if none).
	if ambition_complete or event_id not in ambition_trigger_events:
		return 0
	var gain: int = 15
	ambition_progress = min(100, ambition_progress + gain)
	if ambition_progress >= 100:
		ambition_complete = true
	return gain


func get_ambition_status() -> String:
	if ambition_id.is_empty():
		return "No ambition set"
	if ambition_complete:
		return "FULFILLED: %s" % ambition_label
	return "%s (%d%%)" % [ambition_label, ambition_progress]


# ---- Phobia methods ----

func add_phobia(phobia_id: String) -> void:
	if phobia_id not in phobias:
		phobias.append(phobia_id)


func remove_phobia(phobia_id: String) -> void:
	phobias.erase(phobia_id)
	phobia_exposure_count.erase(phobia_id)


func has_phobia(phobia_id: String) -> bool:
	return phobia_id in phobias


func tick_phobia_exposure(phobia_id: String) -> void:
	## Track consecutive periods of trigger-context stress exposure.
	phobia_exposure_count[phobia_id] = phobia_exposure_count.get(phobia_id, 0) + 1


func reset_phobia_exposure(phobia_id: String) -> void:
	phobia_exposure_count[phobia_id] = 0


# ---- Skill progression methods ----

func gain_skill_xp(skill_name: String, amount: int) -> bool:
	## Award XP toward a skill. Returns true if a level-up occurred.
	skill_xp[skill_name] = skill_xp.get(skill_name, 0) + amount
	var current_level: int = skill_level.get(skill_name, 0)
	var xp_needed: int = _xp_for_level(current_level + 1)
	if skill_xp[skill_name] >= xp_needed and current_level < 2:
		skill_level[skill_name] = current_level + 1
		return true  # Level up!
	return false


func get_skill_modifier(skill_name: String) -> float:
	## Returns flat bonus for skill level: 0=+0.0, 1=+0.1, 2=+0.2.
	return skill_level.get(skill_name, 0) * 0.1


func _xp_for_level(target_level: int) -> int:
	match target_level:
		1: return 50   # Novice → Proficient
		2: return 150  # Proficient → Expert
		_: return 9999


func get_primary_skill() -> String:
	## Returns the primary skill name for this crew role.
	match role:
		"pilot":     return "navigation"
		"engineer":  return "repair"
		"scientist": return "research"
		"security":  return "combat"
		"medic":     return "medicine"
		"diplomat":  return "negotiation"
		_:           return "general"


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
		"relationship_matrix": relationship_matrix,
		"ambition_id": ambition_id,
		"ambition_label": ambition_label,
		"ambition_progress": ambition_progress,
		"ambition_complete": ambition_complete,
		"ambition_trigger_destinations": ambition_trigger_destinations,
		"ambition_trigger_events": ambition_trigger_events,
		"phobias": phobias,
		"phobia_exposure_count": phobia_exposure_count,
		"skill_xp": skill_xp,
		"skill_level": skill_level
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
	ambition_id = data.get("ambition_id", "")
	ambition_label = data.get("ambition_label", "")
	ambition_progress = data.get("ambition_progress", 0)
	ambition_complete = data.get("ambition_complete", false)
	ambition_trigger_destinations = data.get("ambition_trigger_destinations", [])
	ambition_trigger_events = data.get("ambition_trigger_events", [])
	phobias = data.get("phobias", [])
	phobia_exposure_count = data.get("phobia_exposure_count", {})
	skill_xp = data.get("skill_xp", {})
	skill_level = data.get("skill_level", {})
