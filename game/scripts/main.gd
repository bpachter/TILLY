extends Node2D

var tilly_game: TillyGame
var combat_active: bool = false
var is_paused: bool = false

## Test scenario: Demonstrate Earth -> Mars -> Europa route with one encounter


func _ready() -> void:
	print("\n=== TILLY Main Scene ===")
	
	# Initialize core game systems
	tilly_game = TillyGame.new()
	add_child(tilly_game)
	
	# Wait one frame for TillyGame to complete _ready
	await get_tree().process_frame
	
	# Start tutorial scenario
	setup_tutorial_scenario()


func setup_tutorial_scenario() -> void:
	print("\n=== Tutorial Scenario: Earth -> Mars -> Europa ===")
	print("=== With Crew Personality Systems ===")
	
	tilly_game.start_new_game()
	
	# Print crew roster
	print("\nStarting Crew:")
	for crew_member in tilly_game.crew:
		print("  - %s (%s): %s" % [crew_member.name, crew_member.role, crew_member.traits])
	
	# Phase 1: Earth (safe zone)
	print("\n[Phase 1] At Earth Station")
	await simulate_destination("earth", 2.0)
	
	# Trigger a crew-aware event
	var event1 = tilly_game.trigger_crew_aware_event()
	await get_tree().create_timer(1.0).timeout
	
	# Trigger a safe transit event
	print("\n[Phase 2] Transiting to Mars...")
	await simulate_transit_to("mars_colony")
	
	# Phase 2: Mars Colony
	print("\n[Phase 3] Arrived at Mars Colony")
	await simulate_destination("mars_colony", 2.0)
	
	# Advance crew time and trigger cascades
	var cascades = tilly_game.advance_crew_time()
	print("Crew morale update:")
	var morale_status = tilly_game.get_morale_status()
	print("  Average morale: %d" % morale_status.get("average_morale", 0))
	print("  Diagnosis: %s" % morale_status.get("diagnosis", "unknown"))
	await get_tree().create_timer(1.0).timeout
	
	# Trigger a travel event
	print("\n[Phase 4] Transiting to Europa...")
	await simulate_transit_to("europa")
	
	# Phase 3: Europa with encounter
	print("\n[Phase 5] Arrived at Europa - Scanning for life...")
	await simulate_destination("europa", 2.0)
	
	# Trigger combat encounter with stress effects
	print("\n[Phase 6] CONTACT DETECTED - Initiating combat...")
	await simulate_combat("hybrid_scout_01")
	
	# End of tutorial
	print("\n=== Tutorial Complete ===")
	print("Final state: %s" % [tilly_game.game_state.current_destination])
	print("Destinations visited: %s" % [tilly_game.game_state.visited_destinations])


func simulate_destination(dest_id: String, duration: float) -> void:
	tilly_game.game_state.set_destination(dest_id)
	print("Location: %s" % dest_id)
	
	# Simulate cozy downtime events
	for i in range(2):
		await get_tree().create_timer(duration / 2.0).timeout
		var event = tilly_game.trigger_random_event()
		if event.get("triggered", false):
			print("  → Event: %s" % event.get("title", "Unknown"))
			# Show choices to player (placeholder)
			var choices = event.get("choices", [])
			if choices.size() > 0:
				var selected_choice = choices[0]  # Pick first choice for tutorial
				tilly_game.event_resolver.apply_choice(selected_choice)
				print("     Choice: %s" % selected_choice.get("label", "..."))


func simulate_transit_to(dest_id: String) -> void:
	var fuel_cost: int = 15
	tilly_game.game_state.modify_resource("fuel", -fuel_cost)
	print("Fuel consumed: %d (remaining: %d)" % [fuel_cost, tilly_game.game_state.get_resource("fuel")])
	
	await get_tree().create_timer(1.5).timeout
	tilly_game.game_state.set_destination(dest_id)
	print("Arrived at %s" % dest_id)


func simulate_combat(enemy_id: String) -> void:
	if not tilly_game.start_combat_encounter(enemy_id):
		print("ERROR: Failed to start combat")
		return
	
	# Apply stress shock to crew
	tilly_game.apply_stress_shock(25)
	
	combat_active = true
	is_paused = true
	
	# Simulate a few combat ticks
	print("\n=== COMBAT START ===")
	print("Your ship hull: %d | Enemy hull: %d" % [
		tilly_game.combat_engine.combat_state["player_hull"],
		tilly_game.combat_engine.combat_state["enemy_hull"]
	])
	print("\nCrew stress applied (+25)")
	
	# Show crew modifier effects
	var crew_effects = {}
	for crew_member in tilly_game.crew:
		var mods = crew_member.get_trait_modifiers(tilly_game.contract_loader.get_contract("crew_traits"))
		for key in mods:
			crew_effects[key] = crew_effects.get(key, 0.0) + mods[key]
	
	if crew_effects.size() > 0:
		print("Active crew trait modifiers:")
		for key in crew_effects:
			print("  %s: %.2f" % [key, crew_effects[key]])
	
	for tick_count in range(15):
		if tilly_game.combat_engine.is_combat_over():
			break
		
		# Unpause and advance one tick
		tilly_game.combat_engine.set_paused(false)
		tilly_game.advance_combat()
		
		var state = tilly_game.get_combat_state()
		print("Tick %d: You %d HP | Enemy %d HP" % [tick_count + 1, state["player_hull"], state["enemy_hull"]])
		
		await get_tree().create_timer(0.5).timeout
	
	# Show outcome
	var outcome = tilly_game.combat_engine.combat_state["outcome"]
	print("\n=== COMBAT RESULT: %s ===" % outcome.to_upper())
	
	if outcome == "victory":
		print("Enemy defeated!")
		tilly_game.game_state.modify_resource("morale", 20)
	elif outcome == "defeat":
		print("Your ship was destroyed.")
	
	# Check for crew deaths
	var newly_dead = tilly_game.check_post_combat_crew_deaths()
	if not newly_dead.is_empty():
		print("\nCrew losses this battle:")
		for lost in newly_dead:
			print("  ✝ %s (%s)" % [lost.name, lost.role])
	
	var living_crew = tilly_game.get_living_crew()
	print("Crew remaining: %d/%d" % [living_crew.size(), tilly_game.crew.size()])
	
	combat_active = false


func _process(delta: float) -> void:
	# Allow manual pausing during combat
	if Input.is_action_just_pressed("ui_accept"):
		is_paused = !is_paused
		if combat_active:
			tilly_game.combat_engine.set_paused(is_paused)
