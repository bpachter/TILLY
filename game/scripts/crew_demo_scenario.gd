extends Node
class_name CrewDemoScenario

## Demonstration scenario showing crew personality systems in action.
## Tests crew-aware events, morale cascades, and relationship dynamics.

var tilly_game: TillyGame


func _ready() -> void:
	print("=== CREW PERSONALITY DEMO SCENARIO ===\n")
	
	# Get TillyGame instance (should be in parent hierarchy)
	tilly_game = get_parent().get_node("TillyGame") if has_parent() else null
	
	if not tilly_game or not tilly_game.is_initialized:
		print("ERROR: TillyGame not found or not initialized")
		return
	
	run_demo()


func run_demo() -> void:
	print("Starting crew personality demonstration...\n")
	
	# Phase 1: Introduce crew
	print("[PHASE 1] CREW INTRODUCTION")
	print_crew_roster()
	print()
	
	# Phase 2: Trigger crew-aware events
	print("[PHASE 2] CREW-AWARE EVENT SELECTION")
	simulate_event_triggers()
	print()
	
	# Phase 3: Simulate time passage and morale decay
	print("[PHASE 3] TIME PASSAGE & MORALE MANAGEMENT")
	simulate_time_passage()
	print()
	
	# Phase 4: Stress cascade triggers
	print("[PHASE 4] STRESS CASCADE DETECTION")
	simulate_stress_cascades()
	print()
	
	# Phase 5: Combat with crew modifiers
	print("[PHASE 5] COMBAT WITH CREW TRAIT MODIFIERS")
	simulate_combat_with_crew()
	print()
	
	print("=== DEMO COMPLETE ===")


func print_crew_roster() -> void:
	var status = tilly_game.get_morale_status()
	
	for member in status.get("crew_members", []):
		print("  %s (%s)" % [member.get("name", "Unknown"), member.get("status", "UNKNOWN")])
		print("    Role: %s" % tilly_game.crew[tilly_game.crew.size() - 1].role)
		print("    Traits: %s" % tilly_game.crew[tilly_game.crew.size() - 1].traits)
		print("    Morale: %d | Stress: %d | Health: %d" % [
			member.get("morale", 0),
			member.get("stress", 0),
			member.get("health", 100)
		])
		print()


func simulate_event_triggers() -> void:
	# Trigger 3 crew-aware events
	for i in range(3):
		var outcome = tilly_game.trigger_crew_aware_event()
		
		if outcome.is_empty():
			print("  Event %d: [NO EVENT TRIGGERED]" % (i + 1))
		else:
			print("  Event %d: %s" % [i + 1, outcome.get("event_id", "unknown")])
			print("    Success: %s (prob: %.1f%%)" % [
				outcome.get("success", false),
				outcome.get("probability", 0.0) * 100
			])
		
		print()


func simulate_time_passage() -> void:
	# Simulate 5 time periods
	for period in range(5):
		print("  Time Period %d:" % (period + 1))
		
		var cascades = tilly_game.advance_crew_time()
		var status = tilly_game.get_morale_status()
		
		print("    Average Morale: %d | Average Stress: %d" % [
			status.get("average_morale", 0),
			status.get("average_stress", 0)
		])
		print("    Diagnosis: %s" % status.get("diagnosis", "Unknown"))
		
		if cascades.size() > 0:
			print("    Cascades triggered:")
			for cascade in cascades:
				print("      - %s" % cascade.get("type", "unknown"))
		
		print()


func simulate_stress_cascades() -> void:
	# Apply stress to trigger cascades
	print("  Applying high stress to trigger cascades...")
	
	tilly_game.apply_stress_shock(40)
	
	var cascades = tilly_game.advance_crew_time()
	var status = tilly_game.get_morale_status()
	
	print("  After stress shock:")
	print("    Average Morale: %d | Average Stress: %d" % [
		status.get("average_morale", 0),
		status.get("average_stress", 0)
	])
	print("    Panic Count: %d | Crisis Count: %d" % [
		status.get("panic_count", 0),
		status.get("crisis_count", 0)
	])
	
	if cascades.size() > 0:
		print("    Cascades detected:")
		for cascade in cascades:
			var cascade_type = cascade.get("type", "unknown")
			match cascade_type:
				"panic_onset":
					print("      ⚠ Crew member entering panic state")
				"morale_crisis":
					print("      🚨 Crew member experiencing existential crisis")
				"decision_crisis":
					print("      ⚠ Crew member decision-making impaired")
				"bonding_opportunity":
					print("      ✨ Opportunity for crew bonding event")
				"conflict_risk":
					print("      ⚡ Risk of crew conflict escalation")
	
	print()


func simulate_combat_with_crew() -> void:
	print("  Starting combat encounter...")
	
	# Start combat
	if tilly_game.start_combat_encounter("hybrid_scout_01"):
		print("  Enemy: hybrid_scout_01")
		print("  Player Crew Modifiers:")
		
		# Show crew modifiers
		var crew_modifiers = {}
		for crew_member in tilly_game.crew:
			var mods = crew_member.get_trait_modifiers(tilly_game.contract_loader.get_contract("crew_traits"))
			for key in mods:
				crew_modifiers[key] = crew_modifiers.get(key, 0.0) + mods[key]
		
		for key in crew_modifiers:
			print("    %s: %.2f" % [key, crew_modifiers[key]])
		
		# Simulate a few combat ticks
		print("  Combat ticks:")
		for tick in range(5):
			tilly_game.advance_combat()
			var combat_state = tilly_game.get_combat_state()
			
			print("    Tick %d: Player HP %d | Enemy HP %d" % [
				tick + 1,
				combat_state.get("player_hull", 0),
				combat_state.get("enemy_hull", 0)
			])
			
			if tilly_game.combat_engine.is_combat_over():
				var outcome = combat_state.get("outcome", "ongoing")
				print("    Combat ended: %s" % outcome)
				break
	else:
		print("  ERROR: Failed to start combat encounter")
	
	print()


func print_relationship_matrix() -> void:
	print("  CREW RELATIONSHIP MATRIX:")
	
	for i in range(tilly_game.crew.size()):
		print("    %s:" % tilly_game.crew[i].name)
		for j in range(tilly_game.crew.size()):
			if i != j:
				var affinity = tilly_game.crew[i].get_affinity(tilly_game.crew[j].crew_id)
				var relationship_type = "neutral"
				if affinity > 40:
					relationship_type = "close"
				elif affinity > 10:
					relationship_type = "friendly"
				elif affinity < -40:
					relationship_type = "hostile"
				elif affinity < -10:
					relationship_type = "strained"
				
				print("      → %s: %d (%s)" % [
					tilly_game.crew[j].name,
					affinity,
					relationship_type
				])
