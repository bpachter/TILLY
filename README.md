# TILLY

TILLY is a modern pixel-space adventure game with cozy ship-life systems and high-stakes tactical battles.

Name origin:
- TILLY is the ship AI that guides the crew and mission.
- Working expansion: Tactical Intelligence for Lifeform Logistics and Yield.

## Core Premise

You begin at Earth, jump to Mars Colony, and then push deeper into the outer Solar System to search for life and water signatures across destinations like Europa, Enceladus, Ganymede, Titan, Ceres, and Pluto.

The player creates a crew of 3-4 members. Each crew member has randomized personality traits that alter combat behavior, research outcomes, social events, and crisis response.

The ship uses fixed-screen tactical combat inspired by FTL style pacing (pause-and-command, subsystem targeting, crew movement), but with stronger narrative simulation and cozy downtime loops.

## Design Pillars

1. Cozy routines under pressure.
2. Terrifying unknowns in deep space.
3. Emergent crew stories driven by personality systems.
4. Data-driven events and deterministic simulation.
5. Strong replayability through seeds, route choices, and crew variance.

## Initial Repo Plan

- docs/GAME_VISION.md: narrative and design direction
- docs/TECH_ARCHITECTURE.md: systems and engine plan
- docs/CREW_PERSONALITY_SYSTEM.md: modular personality model
- docs/PRODUCTION_ROADMAP.md: milestone and execution plan

## Suggested Tech Start

- Engine: Godot 4 (2D) for game runtime
- Content: JSON-driven events, sectors, crew traits, ships
- Tooling: TypeScript + Vite editor utilities (optional)
- Analytics and balancing: Python scripts

## Next Build Steps

1. Lock vertical slice scope (one destination arc, one enemy faction, one ship).
2. Implement deterministic tactical prototype.
3. Implement personality-driven event resolver.
4. Integrate first playable loop (Earth -> Mars -> one outer moon).
