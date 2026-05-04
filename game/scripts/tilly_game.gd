extends Node
class_name TillyGame

## Main game coordinator and bootstrap.
## Loads contracts, initializes systems, manages game flow.

var rng: TillyRNG
var contract_loader: ContractLoader
var game_state: GameState
var event_resolver: EventResolver
var combat_engine: CombatEngine
var crew_generator: CrewGenerator
var crew_event_integration: CrewEventIntegration
var morale_stress_manager: MoraleStressManager
var crew_ambitions_manager: CrewAmbitionsManager
var crew_mental_health_manager: CrewMentalHealthManager
var crew: Array = []

var is_initialized: bool = false
var last_error: String = ""


func _ready() -> void:
	print("=== TILLY Engine Bootstrap ===")
	if not initialize():
		print("FATAL: Initialization failed")
		print("Errors: " + last_error)
		get_tree().quit()
	else:
		print("TILLY engine initialized successfully")
		print_system_status()


func initialize() -> bool:
	# Step 1: Load and validate contracts
	print("\n[1] Loading game contracts...")
	contract_loader = ContractLoader.new()
	if not contract_loader.load_all():
		last_error = "Contract validation failed"
		contract_loader.print_errors()
		return false
	print("✓ All contracts loaded and validated")
	
	# Step 2: Initialize core systems
	print("\n[2] Initializing core systems...")
	
	# Create RNG with deterministic seed
	var run_seed: int = randi()
	rng = TillyRNG.new(run_seed)
	print("✓ RNG initialized with seed: %d" % run_seed)
	
	# Create game state
	game_state = GameState.new(run_seed)
	print("✓ Game state initialized")
	
	# Create event resolver
	event_resolver = EventResolver.new(game_state, rng)
	print("✓ Event resolver initialized")
	
	# Create combat engine
	combat_engine = CombatEngine.new(rng, game_state)
	print("✓ Combat engine initialized")
	
	# Create crew generator
	crew_generator = CrewGenerator.new(rng)
	print("✓ Crew generator initialized")
	
	# Generate starting crew
	var archetypes_contract = contract_loader.get_contract("crew_archetypes")
	var traits_contract = contract_loader.get_contract("crew_traits")
	crew = crew_generator.generate_crew(3, archetypes_contract, traits_contract)
	print("✓ Crew generated: %d members" % crew.size())
	
	# Set crew on combat engine
	combat_engine.set_crew(crew, traits_contract)
	
	# Create crew event integration system
	crew_event_integration = CrewEventIntegration.new(rng, game_state, crew, traits_contract)
	print("✓ Crew event integration initialized")
	
	# Create morale/stress manager
	morale_stress_manager = MoraleStressManager.new(crew)
	print("✓ Morale/stress manager initialized")
	
	# Register crew death callback
	morale_stress_manager.register_cascade_callback("crew_death", _on_crew_death)
	
	# Create crew ambitions manager and assign personal goals
	crew_ambitions_manager = CrewAmbitionsManager.new(rng, crew)
	crew_ambitions_manager.assign_ambitions()
	print("✓ Crew ambitions assigned")
	
	# Create crew mental health manager
	crew_mental_health_manager = CrewMentalHealthManager.new(rng, crew)
	print("✓ Crew mental health manager initialized")
	
	is_initialized = true
	return true


func print_system_status() -> void:
	print("\n=== TILLY System Status ===")
	print("Contracts Loaded:")
	print("  - crew_traits: %d traits" % contract_loader.get_contract("crew_traits").get("traits", []).size())
	print("  - crew_archetypes: %d archetypes" % contract_loader.get_contract("crew_archetypes").get("archetypes", []).size())
	print("  - destinations: %d locations" % contract_loader.get_contract("destinations").get("destinations", []).size())
	print("  - events: %d events" % contract_loader.get_contract("events").get("events", []).size())
	print("  - enemy_templates: %d enemy types" % contract_loader.get_contract("enemy_templates").get("enemies", []).size())
	print("  - ship_modules: %d modules" % contract_loader.get_contract("ship_modules").get("modules", []).size())
	print("\nCrew Roster:")
	for crew_member in crew:
		print("  - %s (%s) | traits=%s | morale=%d | ambition: %s" % [
			crew_member.name,
			crew_member.role,
			crew_member.traits,
			crew_member.morale,
			crew_member.get_ambition_status()
		])
	print("\nRun Seed: %d" % game_state.run_seed)
	print("Starting Location: %s" % game_state.current_destination)


func start_new_game() -> void:
	print("\n=== Starting New Game ===")
	game_state = GameState.new(rng.next_uint64())
	event_resolver = EventResolver.new(game_state, rng)
	print("New game started at %s with seed %d" % [game_state.current_destination, game_state.run_seed])


func travel_to_destination(dest_id: String) -> void:
	## Unified destination travel that fires all crew hooks.
	game_state.set_destination(dest_id)
	
	# Ambition progress
	var ambition_results = crew_ambitions_manager.notify_destination_reached(dest_id)
	for result in ambition_results:
		var m = result["crew_member"]
		if result["completed"]:
			print("★ %s fulfilled their ambition at %s!" % [m.name, dest_id])
	
	# Mental health: deep-system destinations count as deep_space context
	var deep_system_ids = ["pluto", "ceres", "enceladus", "titan"]
	if dest_id in deep_system_ids:
		crew_mental_health_manager.tick_phobia_exposure("deep_space")


func trigger_random_event() -> Dictionary:
	if not is_initialized:
		return {}
	
	var events_contract: Dictionary = contract_loader.get_contract("events")
	var events: Array = events_contract.get("events", [])
	
	if events.is_empty():
		return {}
	
	# Weight-select an event
	var weights: PackedFloat64Array = PackedFloat64Array()
	for event in events:
		weights.append(event.get("weight", 1.0))
	
	var selected_idx: int = rng.next_weighted_choice(weights)
	var selected_event = events[selected_idx]
	
	print("Event triggered: %s" % selected_event.get("title", "Unknown"))
	
	# Resolve event conditions
	var resolution = event_resolver.resolve_event(selected_event)
	return resolution


func start_combat_encounter(enemy_id: String) -> bool:
	if not is_initialized:
		return false
	
	var enemies_contract: Dictionary = contract_loader.get_contract("enemy_templates")
	if combat_engine.start_encounter(enemy_id, enemies_contract):
		print("Combat encounter started: %s" % enemy_id)
		return true
	else:
		print("Failed to start encounter: unknown enemy %s" % enemy_id)
		return false


func advance_combat() -> void:
	if combat_engine.is_running:
		combat_engine.advance_tick()


func get_current_game_state() -> GameState:
	return game_state


func get_combat_state() -> Dictionary:
	return combat_engine.get_combat_state()


func trigger_crew_aware_event() -> Dictionary:
	## Triggers event based on crew traits and morale state.
	## Higher priority given to events crew is well-suited for.
	
	if not is_initialized:
		return {}
	
	var events_contract: Dictionary = contract_loader.get_contract("events")
	var events: Array = events_contract.get("events", [])
	
	if events.is_empty():
		return {}
	
	# Get event suggestions based on crew state
	var suggestions = crew_event_integration.get_crew_event_suggestions()
	
	# Find suggested events and weight them higher
	var weighted_events: Array = []
	for event in events:
		var event_id = event.get("id", "")
		var weight = event.get("weight", 1.0)
		
		if event_id in suggestions:
			weight *= 3.0  # Triple weight for crew-suggested events
		
		weighted_events.append({"event": event, "weight": weight})
	
	# Select weighted random event
	var weights: PackedFloat64Array = PackedFloat64Array()
	for entry in weighted_events:
		weights.append(entry.get("weight", 1.0))
	
	var selected_idx: int = rng.next_weighted_choice(weights)
	var selected_event = weighted_events[selected_idx].get("event", {})
	
	if selected_event.is_empty():
		return {}
	
	var event_id = selected_event.get("id", "")
	print("Crew-aware event triggered: %s" % selected_event.get("title", "Unknown"))
	
	# Ambition progress: check if this event advances any crew member's goal
	crew_ambitions_manager.notify_event_triggered(event_id)
	
	# Mental health: therapy events can cure phobias
	crew_mental_health_manager.apply_therapy_event(event_id)
	
	# Grant primary skill XP for crew whose role aligns with the event stage
	_grant_event_skill_xp(selected_event)
	
	# Apply event outcome with crew trait modifiers
	var choice = selected_event.get("choices", [{}])[0]
	var outcome = crew_event_integration.apply_event_outcome_with_crew(event_id, choice)
	
	return outcome


func _grant_event_skill_xp(event_data: Dictionary) -> void:
	## Award small XP to relevant crew after events.
	var stage: String = event_data.get("stage", "")
	for member in crew:
		if member.health <= 0:
			continue
		var primary = member.get_primary_skill()
		# Role–stage alignment: pilot gains on transit, engineer on equipment, scientist on surface
		var qualifies: bool = false
		match stage:
			"transit":   qualifies = member.role in ["pilot", "engineer"]
			"surface":   qualifies = member.role in ["scientist", "medic"]
			"orbit":     qualifies = member.role in ["scientist", "diplomat"]
			"downtime":  qualifies = member.role in ["medic", "diplomat"]
		if qualifies:
			var leveled_up = member.gain_skill_xp(primary, 5)
			if leveled_up:
				var lvl_names = ["Novice", "Proficient", "Expert"]
				print("↑ %s is now %s in %s!" % [
					member.name,
					lvl_names[member.skill_level.get(primary, 0)],
					primary
				])


func advance_crew_time() -> Array:
	## Advance crew time state (morale decay, stress recovery, cascades).
	## Returns array of triggered cascade events (panic, crisis, bonding, conflict).
	
	if not is_initialized:
		return []
	
	var cascades = morale_stress_manager.advance_time_period()
	
	for cascade in cascades:
		print("Cascade triggered: %s for %s" % [cascade.get("type", "unknown"), cascade.get("crew_id", "crew")])
	
	return cascades


func get_morale_status() -> Dictionary:
	## Get current crew morale and stress snapshot.
	
	if not is_initialized:
		return {}
	
	var status = morale_stress_manager.get_crew_status_report()
	var diagnosis = morale_stress_manager.diagnose_crew_crisis()
	status["diagnosis"] = diagnosis
	
	return status


func apply_emergency_morale_event() -> void:
	## Trigger an emergency morale-boosting event (crew bonding, celebration).
	
	morale_stress_manager.apply_emergency_morale_boost(20)
	print("Emergency morale event applied: crew morale +20, stress -10")


func apply_stress_shock(magnitude: int = 20) -> void:
	## Apply stress shock (combat, threat, crisis).
	
	morale_stress_manager.apply_emergency_stress_spike(magnitude)
	print("Stress shock applied: crew stress +%d, morale -%d" % [magnitude, magnitude / 2])


func _on_crew_death(dead_member: CrewPersonality, _unused: Variant = null) -> void:
	## Callback fired by MoraleStressManager when a crew member dies.
	## Applies morale penalties to survivors and triggers funeral event.
	
	print("\n⚠ CREW LOST: %s (%s) has died in action." % [dead_member.name, dead_member.role])
	
	# Log to game state
	game_state.add_flag("crew_death_occurred", true)
	var death_count: int = game_state.get_resource("crew_deaths")
	game_state.resources["crew_deaths"] = death_count + 1 if "crew_deaths" in game_state.resources else 1
	
	# Print survivor morale impact
	var living: Array = []
	for member in crew:
		if member.health > 0:
			living.append(member)
	
	print("  Survivors: %d remaining. Morale impact applied." % living.size())
	
	if living.is_empty():
		print("  ALL CREW LOST — game over condition reached.")
		game_state.add_flag("all_crew_dead", true)


func get_living_crew() -> Array:
	## Returns array of crew members who are still alive.
	var living: Array = []
	for member in crew:
		if member.health > 0:
			living.append(member)
	return living


func check_post_combat_crew_deaths() -> Array:
	## After combat, check for any crew deaths and apply consequences.
	## Returns list of crew who died this combat.
	
	var newly_dead: Array = []
	for member in crew:
		var death_key = "death:%s" % member.crew_id
		# Crew with health <= 0 that haven't been processed yet
		if member.health <= 0 and not morale_stress_manager._active_cascades.has(death_key):
			morale_stress_manager.handle_crew_death(member)
			newly_dead.append(member)
	
	# Grant combat skill XP to living crew after any combat
	var living = get_living_crew()
	for member in living:
		var primary = member.get_primary_skill()
		if member.role in ["security", "pilot"]:
			var leveled = member.gain_skill_xp(primary, 10)
			if leveled:
				var lvl_names = ["Novice", "Proficient", "Expert"]
				print("↑ %s leveled up to %s in %s!" % [
					member.name,
					lvl_names[member.skill_level.get(primary, 0)],
					primary
				])
		else:
			# Non-combat roles gain half XP from surviving combat
			member.gain_skill_xp(primary, 5)
	
	# Tick combat phobia exposure for survivors who were stressed
	crew_mental_health_manager.tick_phobia_exposure("combat")
	
	# Advance survival ambition for combat winners
	if combat_engine.combat_state.get("outcome") == "victory":
		crew_ambitions_manager.notify_combat_victory(living)
	
	return newly_dead
