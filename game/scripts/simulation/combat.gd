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
			combat_state["player_hull"] -= damage
		"board_attempt":
			var damage: int = rng.next_int(3, 8)
			combat_state["player_hull"] -= damage
		"shield_boost":
			combat_state["enemy_shielded"] = true


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
	var modifiers: Dictionary = {}
	
	# Aggregate trait modifiers from crew
	for crew_member in crew:
		if crew_member.is_panicked():
			modifiers["attack_damage"] = modifiers.get("attack_damage", 1.0) * 0.7
			modifiers["repair_efficiency"] = modifiers.get("repair_efficiency", 1.0) * 0.8
	
	# Apply trait-specific modifiers
	for crew_member in crew:
		var member_mods = crew_member.get_trait_modifiers(traits_contract)
		for key in member_mods:
			if key.contains("damage"):
				modifiers["attack_damage"] = modifiers.get("attack_damage", 1.0) + member_mods[key] * 0.1
			elif key.contains("repair"):
				modifiers["repair_efficiency"] = modifiers.get("repair_efficiency", 1.0) + member_mods[key] * 0.1
	
	return modifiers


func get_combat_state() -> Dictionary:
	return combat_state.duplicate()


func get_tick_log() -> Array:
	return tick_log.duplicate()


func is_combat_over() -> bool:
	return combat_state.get("outcome") != "ongoing"


func set_paused(paused: bool) -> void:
	combat_state["paused"] = paused
