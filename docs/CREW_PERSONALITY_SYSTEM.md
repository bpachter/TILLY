# Crew Personality System

## Goal

Create crew members that feel like modular, replayable personalities similar to social-sim archetypes, while staying mechanically meaningful.

## Crew Slot Model

- Crew size: 3 or 4.
- Each crew member has:
  - Role
  - Core stats
  - 2 positive traits
  - 1 volatile trait
  - 1 hidden quirk

## Example Roles

1. Pilot
2. Engineer
3. Scientist
4. Security
5. Medic
6. Diplomat

## Trait Categories

1. Operational
- Impacts repair speed, targeting, scan precision.

2. Social
- Impacts conflicts, bonding, morale events.

3. Crisis
- Impacts behavior under fire, hull breach, casualties.

4. Curiosity
- Impacts anomaly decisions and sample risk tolerance.

## Example Traits

- Calm Under Fire: reduced panic chance during combat.
- Hyperfocus: scan speed increase but social decay over long stress windows.
- Empathic: morale recovery boost to adjacent crew.
- Reckless Genius: higher critical repair chance and higher accident chance.
- Suspicious: better infiltration detection and more inter-crew conflict.

## Relationship Layer

- Pair affinity score from -100 to +100.
- Affinity shifts from choices, event outcomes, and shared tasks.
- High affinity unlocks synergy actions.
- Low affinity can trigger command refusal or mistakes.

## Technical Note

Trait effects should be additive modifiers resolved through a unified rule pipeline to avoid hardcoded role-trait exceptions.
