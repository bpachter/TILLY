# TILLY

TILLY is a modern pixel-space adventure game with cozy ship-life systems, high-stakes tactical combat, and deep data-driven simulation.

Name origin:
- TILLY is the ship AI that guides the crew and mission.
- Expansion: Tactical Intelligence for Lifeform Logistics and Yield.

## Vision

You begin at Earth, jump to Mars Colony, and push into the outer Solar System to search for life and water signatures across Europa, Enceladus, Ganymede, Titan, Ceres, Pluto, and beyond.

Each run centers on a user-created crew of 3-4 members with modular randomized personalities. Trait interactions drive emergent behavior in combat, exploration, and social dynamics.

Combat cadence is inspired by fixed-screen tactical encounters with pause-and-command control, while downtime loops build attachment, recovery, and long-term crew identity.

## Engineering Principles

1. Data-contract-first architecture.
2. Deterministic simulation and seeded replayability.
3. Schema validation as a merge gate.
4. Content as production-grade data products.
5. Incremental milestones with observable quality signals.

## Repository Structure

- game/: runtime project skeleton and scenes/scripts
- data/schemas/: versioned JSON schemas for core content contracts
- data/examples/: canonical sample payloads for contract validation
- tools/validation/: local and CI validation tooling
- scripts/: developer entry points
- docs/: design, architecture, ADRs, standards, and roadmap

## Core Docs

- docs/GAME_VISION.md
- docs/TECH_ARCHITECTURE.md
- docs/CREW_PERSONALITY_SYSTEM.md
- docs/PRODUCTION_ROADMAP.md
- docs/DATA_ENGINEERING_STANDARDS.md
- docs/ADR-0001-data-contract-first.md

## Validation Workflow

Local:

1. Install dev dependencies: pip install -r requirements-dev.txt
2. Run validation: powershell -ExecutionPolicy Bypass -File scripts/validate-data.ps1

CI:

- .github/workflows/data-validation.yml enforces schema validation on push and pull request.

## Near-Term Build Plan

1. Complete tactical vertical slice systems.
2. Expand event contracts and authoring surfaces.
3. Add deterministic simulation harness outputs for balancing.
4. Integrate first playable route: Earth -> Mars -> Europa.
