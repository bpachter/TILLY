## TILLY Simulation Engine Core

This folder contains the deterministic simulation backbone for TILLY.

### Key Systems

1. **RNG and Seeding** (`simulation/rng.gd`)
   - Xorshift128+ for deterministic per-seed outcomes
   - Replay consistency via saved seed and RNG state

2. **Contract Loader** (`simulation/contract_loader.gd`)
   - Loads and validates JSON contracts at startup
   - Early failure on schema violations
   - Reference integrity checks

3. **Combat Engine** (`simulation/combat.gd`)
   - Fixed-timestep tick loop
   - Seeded enemy behavior and crew trait resolution
   - State snapshots for replay and balance analysis

4. **Event Resolver** (`simulation/event_resolver.gd`)
   - Condition evaluation pipeline
   - Effect application and state mutation
   - Deterministic choice outcomes

5. **Game State** (`simulation/game_state.gd`)
   - Persistent run state and flags
   - Destination graph and crew roster
   - Save/load serialization

### Determinism Contract

All simulation logic must:
- Use only seeded RNG for randomness
- Accept input via well-defined data contracts
- Produce deterministic output for identical inputs and seed
- Log state transitions for replay and debugging
