# ADR-0001: Data-Contract-First Architecture

## Status
Accepted

## Context

TILLY depends on large authored content surfaces: events, destinations, enemy templates, crew traits, and ship modules. Historically, game teams lose velocity when content grows without strict data contracts.

## Decision

Adopt a data-contract-first architecture with schema validation as a merge gate.

## Rationale

1. Enables safe scaling of content authoring.
2. Reduces runtime defects from malformed data.
3. Supports deterministic simulation and balance experimentation.
4. Improves onboarding and contributor confidence.

## Consequences

Positive:
- Faster and safer content iteration over time.
- Better CI signal quality.
- Lower regression risk in event and combat systems.

Trade-offs:
- Initial overhead to define and maintain schemas.
- Migration work required when contracts evolve.

## Implementation Notes

1. Schemas live in data/schemas.
2. Example payloads live in data/examples.
3. Validation script runs locally and in CI.
4. Contract changes must update docs and samples.
