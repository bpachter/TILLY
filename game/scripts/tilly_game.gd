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
	print("\nCrew Status:")
	for crew_member in crew:
		print("  - %s (%s): traits=%s, morale=%d" % [
			crew_member.name,
			crew_member.role,
			crew_member.traits,
			crew_member.morale
		])
	print("\nRun Seed: %d" % game_state.run_seed)
	print("Starting Location: %s" % game_state.current_destination)


func start_new_game() -> void:
	print("\n=== Starting New Game ===")
	game_state = GameState.new(rng.next_uint64())
	event_resolver = EventResolver.new(game_state, rng)
	print("New game started at %s with seed %d" % [game_state.current_destination, game_state.run_seed])


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
