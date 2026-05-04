extends Node
class_name BalanceAnalysisHarness

## Runs deterministic simulations to gather balance telemetry.
## Outputs: win rates, resource consumption, crew efficiency metrics.

var rng: TillyRNG
var game_state: GameState
var combat_engine: CombatEngine
var crew_generator: CrewGenerator
var crew_event_integration: CrewEventIntegration
var morale_stress_manager: MoraleStressManager
var contract_loader: ContractLoader

var run_count: int = 0
var victory_count: int = 0
var defeat_count: int = 0
var avg_hull_remaining: float = 0.0
var avg_fuel_consumed: float = 0.0
var avg_crew_morale: float = 0.0
var avg_crew_stress: float = 0.0
var trait_win_rate: Dictionary = {}  # track win rates by trait


func _init(p_contract_loader: ContractLoader) -> void:
	contract_loader = p_contract_loader


func run_simulation_sweep(seed_base: int, num_runs: int) -> void:
	print("\n=== BALANCE ANALYSIS SWEEP ===")
	print("Simulating %d deterministic runs..." % num_runs)
	
	for i in range(num_runs):
		var run_seed: int = seed_base + i
		run_single_encounter(run_seed)
		
		if (i + 1) % 100 == 0:
			print("Progress: %d/%d runs completed" % [i + 1, num_runs])
	
	print_results()


func run_single_encounter(run_seed: int) -> void:
	rng = TillyRNG.new(run_seed)
	game_state = GameState.new(run_seed)
	var crew_gen = CrewGenerator.new(rng)
	var morale_mgr = MoraleStressManager.new([])
	combat_engine = CombatEngine.new(rng, game_state)
	
	# Generate crew
	var archetypes_contract = contract_loader.get_contract("crew_archetypes")
	var traits_contract = contract_loader.get_contract("crew_traits")
	var crew = crew_gen.generate_crew(3, archetypes_contract, traits_contract)
	morale_mgr = MoraleStressManager.new(crew)
	
	# Create event integration
	crew_event_integration = CrewEventIntegration.new(rng, game_state, crew, traits_contract)
	
	# Set crew on combat engine
	combat_engine.set_crew(crew, traits_contract)
	
	# Track crew traits for stats
	for crew_member in crew:
		for trait_id in crew_member.traits:
			if not trait_win_rate.has(trait_id):
				trait_win_rate[trait_id] = {"wins": 0, "losses": 0}
	
	# Start encounter with random enemy
	var enemies_contract = contract_loader.get_contract("enemy_templates")
	var enemies = enemies_contract.get("enemies", [])
	if enemies.size() > 0:
		var random_enemy = enemies[rng.next_int(0, enemies.size())]
		combat_engine.start_encounter(random_enemy.get("id", ""), enemies_contract)
	
	# BUG-FIX #9: Unpause so advance_tick() actually runs.
	combat_engine.set_paused(false)
	
	# Simulate combat until outcome
	for tick in range(100):  # Max 100 ticks per encounter
		if combat_engine.is_combat_over():
			break
		combat_engine.advance_tick()
	
	# Collect results
	var outcome = combat_engine.combat_state.get("outcome", "ongoing")
	if outcome == "victory":
		victory_count += 1
		avg_hull_remaining += combat_engine.combat_state.get("player_hull", 0)
		
		# Track crew trait wins
		for crew_member in crew:
			for trait_id in crew_member.traits:
				trait_win_rate[trait_id]["wins"] += 1
	elif outcome == "defeat":
		defeat_count += 1
		
		# Track crew trait losses
		for crew_member in crew:
			for trait_id in crew_member.traits:
				trait_win_rate[trait_id]["losses"] += 1
	
	# Track morale/stress over run
	var status = morale_mgr.get_crew_status_report()
	avg_crew_morale += status.get("average_morale", 50)
	avg_crew_stress += status.get("average_stress", 50)
	
	run_count += 1


func print_results() -> void:
	print("\n=== BALANCE ANALYSIS RESULTS ===")
	print("Total runs: %d" % run_count)
	print("Victories: %d (%.1f%%)" % [victory_count, float(victory_count) / max(1, run_count) * 100])
	print("Defeats: %d (%.1f%%)" % [defeat_count, float(defeat_count) / max(1, run_count) * 100])
	
	if victory_count > 0:
		print("Average hull remaining (victories): %.1f" % (avg_hull_remaining / victory_count))
	
	print("Average crew morale: %.1f" % (avg_crew_morale / max(1, run_count)))
	print("Average crew stress: %.1f" % (avg_crew_stress / max(1, run_count)))
	
	print("\n=== TRAIT EFFECTIVENESS ===")
	for trait_id in trait_win_rate:
		var stats = trait_win_rate[trait_id]
		var total = stats["wins"] + stats["losses"]
		var win_rate = float(stats["wins"]) / max(1, total) * 100
		print("  %s: %.1f%% (%d/%d)" % [trait_id, win_rate, stats["wins"], total])
	
	print("\nRecommendations:")
	var win_rate = float(victory_count) / max(1, run_count)
	if win_rate > 0.7:
		print("- Player has too high win rate. Consider increasing enemy difficulty.")
	elif win_rate < 0.3:
		print("- Player has too low win rate. Consider decreasing enemy difficulty.")
	else:
		print("- Win rate is balanced (30-70% range).")

