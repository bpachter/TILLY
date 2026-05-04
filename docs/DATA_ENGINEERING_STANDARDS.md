# Data Engineering Standards

## Principle

Treat game content as production data products.

## Non-Negotiables

1. All gameplay content must be validated against versioned schemas before merge.
2. No direct content changes without deterministic validation output.
3. Every schema change requires:
   - version bump
   - migration note
   - backward compatibility decision
4. Seeded simulation paths must be replayable.
5. Data contracts are API contracts.

## Data Quality Gates

1. Structural validation
- JSON Schema compliance for every content file.

2. Referential validation
- IDs referenced by events, destinations, modules, enemies, and traits must exist.

3. Domain validation
- Probability values in [0,1].
- Weights non-negative.
- Cooldowns and durations non-negative.
- Enumerations constrained.

4. Determinism validation
- Same seed and input payload must produce same output sequence.

## Naming Conventions

- IDs are lowercase snake_case.
- Schema files are versioned with top-level schema_version.
- Numeric balancing fields include explicit units in field names where useful.

## Branching and Change Control

1. Feature branches only.
2. Pull request required for main.
3. PR checklist must include data validation evidence.
4. High-risk balance changes must include simulation report snapshots.

## Observability

- Validation scripts produce machine-readable output and human summary.
- Simulation runs export seed, config hash, and result digest.

## Tooling Baseline

- Python validator for schema checks.
- CI gate on every pull request.
- Local PowerShell wrapper for one-command validation.
