extends Node
class_name ShipLoadout

## Manages which ship modules are currently installed and translates their
## tags and slot types into concrete stat bonuses usable by CombatEngine,
## CrewEventIntegration, and other systems.
##
## Bonuses by tag:
##   "damage" / "tracking"   → +0.12 attack_damage per module
##   "repair" / "automation" → +0.15 repair_efficiency per module
##   "armor" / "impact"      → +8 starting_hull bonus (applied at encounter start)
##   "medicine" / "recovery" → +0.10 repair_efficiency + crew health regen flag
##   "analysis" / "research" → +0.20 science_event_bonus (used in event integration)
##   "biosample"             → +0.10 science_event_bonus
##
## Power: sum of power_draw must not exceed game_state.resources["power_available"].
## Modules that exceed capacity are degraded (bonuses halved).

var equipped_modules: Array = []    # Array of module Dictionaries from contract
var power_available: int = 10       # Pulled from game_state at equip time


const TAG_BONUSES: Dictionary = {
	"damage":     {"stat": "attack_damage",      "amount": 0.12},
	"tracking":   {"stat": "attack_damage",      "amount": 0.12},
	"repair":     {"stat": "repair_efficiency",  "amount": 0.15},
	"automation": {"stat": "repair_efficiency",  "amount": 0.15},
	"armor":      {"stat": "hull_bonus",         "amount": 8.0},
	"impact":     {"stat": "hull_bonus",         "amount": 6.0},
	"medicine":   {"stat": "repair_efficiency",  "amount": 0.10},
	"recovery":   {"stat": "repair_efficiency",  "amount": 0.08},
	"analysis":   {"stat": "science_bonus",      "amount": 0.20},
	"research":   {"stat": "science_bonus",      "amount": 0.15},
	"biosample":  {"stat": "science_bonus",      "amount": 0.10}
}


func _init(p_power_available: int = 10) -> void:
	power_available = p_power_available


func equip_module(module_data: Dictionary) -> bool:
	## Equip a module if power allows. Returns false if over capacity.
	var total_draw = get_total_power_draw() + module_data.get("power_draw", 0)
	if total_draw > power_available:
		return false
	equipped_modules.append(module_data)
	return true


func equip_starting_loadout(modules_contract: Dictionary, rng: TillyRNG) -> void:
	## Select a starting set of modules based on available power.
	## Tries to equip one utility, one defense/offense, and one science/life_support.
	var all_modules: Array = modules_contract.get("modules", [])
	if all_modules.is_empty():
		return
	
	# Group by slot type
	var by_slot: Dictionary = {}
	for m in all_modules:
		var slot = m.get("slot_type", "utility")
		if slot not in by_slot:
			by_slot[slot] = []
		by_slot[slot].append(m)
	
	# Priority slot order for starting loadout
	var priority_slots: Array = ["utility", "defense", "science", "offense", "life_support"]
	for slot in priority_slots:
		if slot not in by_slot:
			continue
		var candidates: Array = by_slot[slot]
		var idx: int = rng.next_int(0, candidates.size() - 1)
		equip_module(candidates[idx])
	
	print("✓ Ship loadout equipped: %d modules (power draw: %d/%d)" % [
		equipped_modules.size(), get_total_power_draw(), power_available
	])
	for m in equipped_modules:
		print("  ▸ [%s] %s (pwr: %d, dur: %d)" % [
			m.get("slot_type", "?"),
			m.get("id", "?"),
			m.get("power_draw", 0),
			m.get("durability", 0)
		])


func get_total_power_draw() -> int:
	var total: int = 0
	for m in equipped_modules:
		total += m.get("power_draw", 0)
	return total


func get_stat_bonus(stat_name: String) -> float:
	## Sums all module bonuses for a given stat key.
	var total: float = 0.0
	for module in equipped_modules:
		var draw: int = module.get("power_draw", 0)
		var powered: bool = get_total_power_draw() <= power_available
		var multiplier: float = 1.0 if powered else 0.5
		
		for tag in module.get("tags", []):
			var bonus_def: Dictionary = TAG_BONUSES.get(tag, {})
			if bonus_def.get("stat", "") == stat_name:
				total += bonus_def.get("amount", 0.0) * multiplier
	
	return total


func get_hull_bonus() -> int:
	return int(get_stat_bonus("hull_bonus"))


func get_science_bonus() -> float:
	return get_stat_bonus("science_bonus")


func has_tag(tag: String) -> bool:
	for m in equipped_modules:
		if tag in m.get("tags", []):
			return true
	return false


func serialize() -> Array:
	var result: Array = []
	for m in equipped_modules:
		result.append(m.get("id", ""))
	return result


func deserialize(module_ids: Array, modules_contract: Dictionary) -> void:
	equipped_modules.clear()
	var all_modules: Array = modules_contract.get("modules", [])
	for mid in module_ids:
		for m in all_modules:
			if m.get("id", "") == mid:
				equipped_modules.append(m)
				break
