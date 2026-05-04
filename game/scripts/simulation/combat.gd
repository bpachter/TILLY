extends Node
class_name CombatEngine

## Deterministic fixed-timestep combat simulation.
## All outcomes are seeded and replayable.

const TICK_RATE: float = 1.0 / 30.0

var rng: TillyRNG
var game_state: GameState
var crew: Array = []
var traits_contract: Dictionary = {}
var enemy_template: Dictionary = {}
var player_ship: Dictionary = {}
var enemy_ship: Dictionary = {}
var combat_state: Dictionary = {}
var tick_log: Array = []
var is_running: bool = false


func _init(p_rng: TillyRNG, p_game_state: GameState) -> void:
	rng = p_rng
	game_state = p_game_state


func set_crew(p_crew: Array, p_traits_contract: Dictionary) -> void:
	crew = p_crew
	traits_contract = p_traits_contract


func start_encounter(enemy_id: String, enemy_templates_contract: Dictionary) -> bool:
	# Find enemy template
	var enemies = enemy_templates_contract.get("enemies", [])
	enemy_template = {}
	
	for enemy in enemies:
		if enemy.get("id") == enemy_id:
			enemy_template = enemy
			break
	
	if enemy_template.is_empty():
		return false
	
	# Initialize combat state
	combat_state = {
		"player_hull": game_state.get_resource("hull_integrity"),
		"enemy_hull": enemy_template.get("hull", 20),
		"player_shielded": false,
		"enemy_shielded": false,
		"tick": 0,
		"paused": true,
		"outcome": "ongoing"
	}
	
	player_ship = {
		"hull": game_state.get_resource("hull_integrity"),
		"subsystems": ["engines", "shields", "life_support", "sensors", "lab", "weapons"],
		"crew_positions": [0, 1, 2]  # Crew member indices at positions
	}
	
	enemy_ship = {
		"hull": enemy_template.get("hull", 20),
		"faction": enemy_template.get("faction", "unknown"),
		"subsystems": enemy_template.get("subsystems", []),
		"behavior": enemy_template.get("behavior_profile", {})
	}
	
	is_running = true
	tick_log.clear()
	
	var log_entry = {
		"tick": 0,
		"type": "encounter_start",
		"enemy_id": enemy_id,
		"player_hull": player_ship["hull"],
		"enemy_hull": enemy_ship["hull"],
		"rng_state": rng.get_state()
	}
	tick_log.append(log_entry)
	
	return true


func advance_tick() -> Dictionary:
	if not is_running or combat_state.get("paused", true):
		return combat_state
	
	combat_state["tick"] += 1
	var tick: int = combat_state["tick"]
	
	# Simulate enemy action
	var enemy_action = get_enemy_action(tick)
	apply_enemy_action(enemy_action)
	
	# Check win/loss conditions
	if combat_state["player_hull"] <= 0:
		combat_state["outcome"] = "defeat"
		is_running = false
	elif combat_state["enemy_hull"] <= 0:
		combat_state["outcome"] = "victory"
		is_running = false
	
	var log_entry = {
		"tick": tick,
		"type": "combat_tick",
		"enemy_action": enemy_action,
		"player_hull": combat_state["player_hull"],
		"enemy_hull": combat_state["enemy_hull"],
		"outcome": combat_state["outcome"],
		"rng_state": rng.get_state()
	}
	tick_log.append(log_entry)
	
	return combat_state


func get_enemy_action(tick: int) -> String:
	var behavior = enemy_ship.get("behavior", {})
	var aggression: float = behavior.get("aggression", 0.5)
	var boarding_bias: float = behavior.get("boarding_bias", 0.3)
	
	# Simple stochastic behavior based on seeded RNG
	var roll: float = rng.next_float()
	
	if roll < boarding_bias:
		return "board_attempt"
	elif roll < boarding_bias + aggression:
		return "weapon_attack"
	else:
		return "shield_boost"


func apply_enemy_action(action: String) -> void:
	match action:
		"weapon_attack":
			var damage: int = rng.next_int(8, 16)
			# BUG-FIX #8: Clamp player hull to 0 minimum.
			combat_state["player_hull"] = max(0, combat_state["player_hull"] - damage)
			# 30% chance a random crew member takes hull-breach injury
			if rng.next_float() < 0.3:
				_apply_crew_combat_damage(rng.next_int(8, 18))
		"board_attempt":
			var damage: int = rng.next_int(3, 8)
			combat_state["player_hull"] = max(0, combat_state["player_hull"] - damage)
			# Boarding always injures crew
			_apply_crew_combat_damage(rng.next_int(12, 22))
		"shield_boost":
			combat_state["enemy_shielded"] = true


func _apply_crew_combat_damage(amount: int) -> void:
	## Apply combat injury to a random living crew member.
	## Returns the crew member damaged, or null if no living crew.
	
	var living_crew: Array = []
	for member in crew:
		if member.health > 0:
			living_crew.append(member)
	
	if living_crew.is_empty():
		return
	
	var target_idx: int = rng.next_int(0, living_crew.size())
	var target = living_crew[target_idx]
	var prev_health: int = target.health
	target.health = max(0, target.health - amount)
	
	# Log crew injury/death
	var log_entry = {
		"tick": combat_state.get("tick", 0),
		"type": "crew_injured",
		"crew_id": target.crew_id,
		"crew_name": target.name,
		"damage": amount,
		"health_before": prev_health,
		"health_after": target.health
	}
	
	if target.health <= 0 and prev_health > 0:
		log_entry["type"] = "crew_killed"
		combat_state["crew_deaths"] = combat_state.get("crew_deaths", 0) + 1
	
	tick_log.append(log_entry)


func apply_player_action(action: String) -> void:
	# Calculate crew trait modifiers
	var crew_modifiers = calculate_crew_modifiers()
	
	match action:
		"attack_weapons":
			var base_damage: int = rng.next_int(6, 14)
			var damage_mod: float = crew_modifiers.get("attack_damage", 1.0)
			var final_damage: int = int(base_damage * damage_mod)
			combat_state["enemy_hull"] -= final_damage
		"repair":
			var base_heal: int = rng.next_int(4, 10)
			var heal_mod: float = crew_modifiers.get("repair_efficiency", 1.0)
			var final_heal: int = int(base_heal * heal_mod)
			combat_state["player_hull"] = min(combat_state["player_hull"] + final_heal, 100)
		"shield_up":
			combat_state["player_shielded"] = true


func calculate_crew_modifiers() -> Dictionary:
	var modifiers: Dictionary = {"attack_damage": 1.0, "repair_efficiency": 1.0}
	
	# Panic penalty: panicked crew members reduce effectiveness
	for crew_member in crew:
		if crew_member.health <= 0:
			continue  # Dead crew don't affect combat
		if crew_member.is_panicked():
			modifiers["attack_damage"] *= 0.7
			modifiers["repair_efficiency"] *= 0.8
	
	# Apply trait-specific modifiers from all living crew
	for crew_member in crew:
		if crew_member.health <= 0:
			continue
		var member_mods = crew_member.get_trait_modifiers(traits_contract)
		for key in member_mods:
			if key.contains("damage"):
				modifiers["attack_damage"] += member_mods[key] * 0.1
			elif key.contains("repair"):
				modifiers["repair_efficiency"] += member_mods[key] * 0.1
	
	# Relationship specialization bonuses for high-affinity crew pairs
	var spec_bonus = _calculate_specialization_bonus()
	modifiers["attack_damage"] += spec_bonus.get("attack_damage", 0.0)
	modifiers["repair_efficiency"] += spec_bonus.get("repair_efficiency", 0.0)
	
	return modifiers


func _calculate_specialization_bonus() -> Dictionary:
	## High-affinity crew pairs unlock role-based combat bonuses.
	## Thresholds: affinity > 60 = minor, affinity > 80 = major bonus.
	
	var bonus: Dictionary = {}
	const MINOR_AFFINITY: int = 60
	const MAJOR_AFFINITY: int = 80
	
	for i in range(crew.size()):
		if crew[i].health <= 0:
			continue
		for j in range(i + 1, crew.size()):
			if crew[j].health <= 0:
				continue
			
			var affinity = crew[i].get_affinity(crew[j].crew_id)
			if affinity < MINOR_AFFINITY:
				continue
			
			var tier: float = 0.1 if affinity >= MAJOR_AFFINITY else 0.05
			var roles = [crew[i].role, crew[j].role]
			roles.sort()  # Canonical order for pair matching
			
			# Pilot + Engineer: navigation precision → attack damage bonus
			if roles == ["engineer", "pilot"]:
				bonus["attack_damage"] = bonus.get("attack_damage", 0.0) + tier
			# Engineer + Medic: damage control expertise → repair bonus
			elif roles == ["engineer", "medic"]:
				bonus["repair_efficiency"] = bonus.get("repair_efficiency", 0.0) + tier * 1.5
			# Pilot + Security: combat maneuvers → attack damage bonus
			elif roles == ["pilot", "security"]:
				bonus["attack_damage"] = bonus.get("attack_damage", 0.0) + tier * 1.5
			# Scientist + any: innovation bonus → both stats
			elif "scientist" in roles:
				bonus["attack_damage"] = bonus.get("attack_damage", 0.0) + tier * 0.5
				bonus["repair_efficiency"] = bonus.get("repair_efficiency", 0.0) + tier * 0.5
	
	return bonus


func get_combat_state() -> Dictionary:
	return combat_state.duplicate()


func get_tick_log() -> Array:
	return tick_log.duplicate()


func is_combat_over() -> bool:
	return combat_state.get("outcome") != "ongoing"


func set_paused(paused: bool) -> void:
	combat_state["paused"] = paused
