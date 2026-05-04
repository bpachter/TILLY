# Vertical Slice Backlog

## Objective

Deliver a 30-45 minute playable route demonstrating the TILLY identity:
Earth -> Mars Colony -> Europa.

## Epic 1: Tactical Combat Core

1. Fixed-screen ship battle scene.
2. Power allocation system for subsystems.
3. Crew movement and repair actions.
4. Enemy action scheduler and targeting logic.
5. Win/loss conditions and battle summary payload.

## Epic 2: Exploration and Route Loop

1. Destination graph ingestion from validated contracts.
2. Jump planning UI and resource costs.
3. Scan and sample extraction action.
4. Transit and orbit event triggers.

## Epic 3: Crew Personality Engine

1. Crew generator with role + trait composition.
2. Trait modifier resolver pipeline.
3. Relationship matrix and event hooks.
4. Crisis behaviors under stress thresholds.

## Epic 4: Data Platform

1. Contract validation gate in CI.
2. Cross-reference and domain-rule checks.
3. Seeded simulation harness skeleton.
4. Balance report artifacts.

## Epic 5: UX and Atmosphere

1. Readable tactical UI hierarchy.
2. Cozy downtime state between encounters.
3. Threat telegraphing and panic cues.
4. Tutorialized first run.

## Definition of Done

1. Deterministic replay for same seed.
2. No schema violations.
3. No unresolved content references.
4. New content includes tests or validation evidence.
5. Performance holds stable target frame time during battle.
