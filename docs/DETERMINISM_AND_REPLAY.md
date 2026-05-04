# Deterministic Simulation and Replay

## Principles

All TILLY simulation must be deterministic for identical seeds and inputs.

## RNG (tilly_rng.gd)

- Xorshift128+ PRNG seeded at run start.
- All randomness flows through this singleton instance.
- Seeded RNG ensures replays are bit-identical.

## Combat Engine (combat.gd)

- Fixed timestep (1/30s per tick).
- All enemy behavior is seeded and logged.
- Tick log records RNG state after each action.
- Same seed + same input sequence = same outcome.

## Game State (game_state.gd)

- Immutable contract: resources, flags, crew, destination.
- Serializable via serialize() and deserialize().
- Used for save/load and replay snapshots.

## Event Resolver (event_resolver.gd)

- Conditions are evaluated deterministically.
- Effects apply in order and are reversible.
- Seeded choice selection via rng.next_weighted_choice().

## Replay and Balancing

To replay a saved run:
1. Load GameState snapshot (which contains original run_seed).
2. Initialize TillyRNG with run_seed.
3. Re-execute event sequence using same player choices.
4. Combat outcomes must match tick-for-tick.

To use simulation for balance analysis:
1. Run 1000 deterministic encounters with N seeds.
2. Aggregate win rates, resource consumption, crew losses.
3. Adjust enemy templates or crew traits.
4. Re-run to verify balance change impact.

## Testing Determinism

Unit test template:

```gdscript
func test_combat_replay() -> void:
	var seed_val: int = 12345
	var rng1 = TillyRNG.new(seed_val)
	var state1 = GameState.new(seed_val)
	var combat1 = CombatEngine.new(rng1, state1)
	
	combat1.start_encounter("hybrid_scout_01", enemy_contract)
	for i in range(10):
		combat1.advance_tick()
	var log1 = combat1.get_tick_log()
	
	# Now replay with fresh instances
	var rng2 = TillyRNG.new(seed_val)
	var state2 = GameState.new(seed_val)
	var combat2 = CombatEngine.new(rng2, state2)
	
	combat2.start_encounter("hybrid_scout_01", enemy_contract)
	for i in range(10):
		combat2.advance_tick()
	var log2 = combat2.get_tick_log()
	
	# Logs should be identical
	assert_equal(log1, log2)
```
