extends Node
class_name CrewEventIntegration

## Crew trait-aware event evaluation and outcome branching.
## Ties crew personality traits to event success/failure probabilities and branching paths.

var rng: TillyRNG
var game_state: GameState
var crew: Array = []
var traits_contract: Dictionary = {}
var mental_health_manager = null  # Optional: CrewMentalHealthManager injection
var ship_loadout = null            # Optional: ShipLoadout injection

# Event outcome modifiers based on crew traits
var trait_event_affinity: Dictionary = {
	"calm_under_fire": ["meteor_shower", "cosmic_radiation_surge", "crew_conflict"],
	"curious_explorer": ["surface_scan_success", "encrypted_distress_signal"],
	"empathic_listener": ["crew_bonding_dinner", "crew_conflict", "quiet_night_reflection"],
	"hyperfocus": ["equipment_malfunction", "experimental_upgrade"],
	"suspicious": ["rogue_ai_contact", "encrypted_distress_signal"],
	"brave_heart": ["board_attempt", "rescue_mission"],
	"green_thumb": ["garden_harvest", "water_ice_deposit"],
	"pessimist": ["quiet_night_reflection"],  # ironic comfort
	"cautious": ["meteor_shower", "surface_contamination_risk"],
	"intuitive": ["anomaly_detection", "gravity_anomaly"],
	"night_owl": ["quiet_night_reflection"],
	"reckless_genius": ["experimental_upgrade"]
}


func _init(p_rng: TillyRNG, p_game_state: GameState, p_crew: Array, p_traits_contract: Dictionary) -> void:
	rng = p_rng
	game_state = p_game_state
	crew = p_crew
	traits_contract = p_traits_contract


func calculate_event_success_probability(event_id: String) -> float:
	## Base success rate modified by crew traits.
	## Returns float 0.0-1.0 representing likelihood of favorable outcome.
	
	var base_probability: float = 0.5
	var crew_modifier: float = 0.0
	
	# Check each crew member for trait affinity
	for crew_member in crew:
		if crew_member.health <= 0:
			continue  # Dead crew don't contribute
		
		# BUG-FIX #7: Apply panic penalty once per crew member, outside the trait loop.
		if crew_member.is_panicked():
			crew_modifier -= 0.2
		
		for trait_id in crew_member.traits:
			var affinity_events = trait_event_affinity.get(trait_id, [])
			if event_id in affinity_events:
				crew_modifier += 0.15  # +15% per matching trait
	
	# Morale bonus: high morale crew more likely to succeed
	var avg_morale: float = 0.0
	var living_count: int = 0
	for crew_member in crew:
		if crew_member.health > 0:
			avg_morale += crew_member.morale
			living_count += 1
	avg_morale /= max(1, living_count)
	
	var morale_modifier: float = (avg_morale - 50.0) / 100.0 * 0.2  # ±10% based on morale
	
	# Phobia penalties: active phobias reduce event success in matching contexts
	var phobia_penalty: float = 0.0
	if mental_health_manager:
		for crew_member in crew:
			if crew_member.health > 0:
				phobia_penalty += mental_health_manager.get_phobia_event_penalty(crew_member, event_id)
	
	# Ship science module bonus on surface/orbit stages
	var loadout_bonus: float = 0.0
	if ship_loadout:
		var stage = ""  # We don't have stage here, use science bonus broadly
		loadout_bonus = ship_loadout.get_science_bonus() * 0.5  # Half bonus in events
	
	return clamp(base_probability + crew_modifier + morale_modifier + phobia_penalty + loadout_bonus, 0.0, 1.0)


func apply_event_outcome_with_crew(event_id: String, choice_data: Dictionary) -> Dictionary:
	## Execute event outcome, potentially with branching based on crew traits.
	
	var success_prob = calculate_event_success_probability(event_id)
	var rolled_success = rng.next_float() < success_prob
	
	var base_effects = choice_data.get("effects", [])
	var outcome_effects = base_effects.duplicate(true)
	
	# Apply crew-specific effect modifications
	if rolled_success:
		# Successful outcome: boost morale, reduce stress
		for crew_member in crew:
			crew_member.recover_stress(5)
			crew_member.morale = min(100, crew_member.morale + 3)
	else:
		# Failed outcome: increase stress, reduce morale
		for crew_member in crew:
			crew_member.apply_stress(8)
			crew_member.morale = max(0, crew_member.morale - 5)
	
	return {
		"event_id": event_id,
		"success": rolled_success,
		"probability": success_prob,
		"effects": outcome_effects
	}


func get_crew_event_suggestions() -> Array:
	## Suggest events based on current crew state and relationships.
	## Returns array of event IDs more likely to succeed with current crew.
	
	var suggestions: Array = []
	
	# High affinity crew pairs can trigger bonding events
	for i in range(crew.size()):
		for j in range(i + 1, crew.size()):
			var affinity = crew[i].get_affinity(crew[j].crew_id)
			if affinity > 60:
				suggestions.append("crew_bonding_dinner")
			elif affinity < -40:
				suggestions.append("crew_conflict")
	
	# Low morale crew benefit from downtime events
	var avg_morale = 0.0
	for crew_member in crew:
		avg_morale += crew_member.morale
	avg_morale /= max(1, crew.size())
	
	if avg_morale < 40:
		suggestions.append("quiet_night_reflection")
		suggestions.append("crew_birthday")
	
	# High stress crew need recovery
	var avg_stress = 0.0
	for crew_member in crew:
		avg_stress += crew_member.stress
	avg_stress /= max(1, crew.size())
	
	if avg_stress > 60:
		suggestions.append("crew_bonding_dinner")
		suggestions.append("garden_harvest")
	
	return suggestions


func create_crew_relationship_event(crew_a_id: String, crew_b_id: String) -> Dictionary:
	## Create dynamic event based on crew relationship.
	
	var crew_a = null
	var crew_b = null
	
	for member in crew:
		if member.crew_id == crew_a_id:
			crew_a = member
		if member.crew_id == crew_b_id:
			crew_b = member
	
	if not crew_a or not crew_b:
		return {}
	
	var affinity = crew_a.get_affinity(crew_b_id)
	
	if affinity > 50:
		return {
			"id": "crew_bonding_%s_%s" % [crew_a_id, crew_b_id],
			"title": "%s and %s: Bonding Moment" % [crew_a.name, crew_b.name],
			"stage": "downtime",
			"weight": 2.0,
			"conditions": [],
			"choices": [
				{
					"id": "encourage_bonding",
					"label": "Spend time together",
					"effects": [
						{ "target": "resource:morale", "operation": "add", "value": 10 },
						{ "target": "crew_affinity_%s_%s" % [crew_a_id, crew_b_id], "operation": "add", "value": 5 }
					]
				}
			]
		}
	elif affinity < -40:
		return {
			"id": "crew_conflict_%s_%s" % [crew_a_id, crew_b_id],
			"title": "%s and %s: Tension Rising" % [crew_a.name, crew_b.name],
			"stage": "downtime",
			"weight": 1.5,
			"conditions": [],
			"choices": [
				{
					"id": "mediate_conflict",
					"label": "Mediate their dispute",
					"effects": [
						{ "target": "crew_affinity_%s_%s" % [crew_a_id, crew_b_id], "operation": "add", "value": 10 },
						{ "target": "resource:morale", "operation": "add", "value": -5 }
					]
				},
				{
					"id": "let_tension_build",
					"label": "Let them work it out",
					"effects": [
						{ "target": "crew_affinity_%s_%s" % [crew_a_id, crew_b_id], "operation": "add", "value": -10 },
						{ "target": "resource:morale", "operation": "add", "value": -15 }
					]
				}
			]
		}
	
	return {}
