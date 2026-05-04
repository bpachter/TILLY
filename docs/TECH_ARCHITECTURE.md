# TILLY Technical Architecture

## Runtime Recommendation

- Godot 4 (2D) for core game.
- Fixed timestep simulation loop for deterministic outcomes.
- Seeded RNG at run start for reproducibility.

## Core Systems

1. Navigation system
- Sector graph and route costs.
- Destination threat and anomaly weighting.

2. Ship simulation
- Subsystems: engines, shields, life support, sensors, lab, weapons.
- Power allocation and damage model.
- Crew position and task queue.

3. Tactical combat
- Pause-and-command timeline.
- Subsystem targeting.
- Boarding and counter-boarding.
- Enemy AI behavior tree plus modifiers.

4. Exploration and sampling
- Scan minigame or timed risk action.
- Sample quality tiers and contamination states.
- Lab processing for unlocks.

5. Event engine
- JSON-authored events with conditions and effects.
- State flags, branching outcomes, and weighted choices.

6. Crew personality engine
- Modular trait packs applied to generated crew.
- Trait triggers in combat, dialogue, and downtime.
- Relationship matrix between crew members.

## Data Contracts (first pass)

- crew_traits.json
- crew_archetypes.json
- destinations.json
- events.json
- enemy_templates.json
- ship_modules.json

## Testing Strategy

1. Determinism tests for same seed outcomes.
2. Event validation tests for broken references.
3. Balance simulation sweeps using scripted runs.
4. Save/load consistency tests.
