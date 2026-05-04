import json
import sys
from pathlib import Path

from jsonschema import Draft202012Validator


REPO_ROOT = Path(__file__).resolve().parents[2]
SCHEMA_DIR = REPO_ROOT / "data" / "schemas"
EXAMPLE_DIR = REPO_ROOT / "data" / "examples"


PAIRS = [
    ("crew_traits.schema.json", "crew_traits.json"),
    ("crew_archetypes.schema.json", "crew_archetypes.json"),
    ("destinations.schema.json", "destinations.json"),
    ("events.schema.json", "events.json"),
    ("enemy_templates.schema.json", "enemy_templates.json"),
    ("ship_modules.schema.json", "ship_modules.json"),
]


class ValidationErrorAccumulator:
    def __init__(self):
        self.errors = []

    def add(self, message: str) -> None:
        self.errors.append(message)

    def has_errors(self) -> bool:
        return len(self.errors) > 0

    def print(self) -> None:
        for idx, error in enumerate(self.errors, start=1):
            print(f"{idx}. {error}")


def load_json(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def validate_schema_pair(schema_name: str, data_name: str, acc: ValidationErrorAccumulator) -> dict:
    schema_path = SCHEMA_DIR / schema_name
    data_path = EXAMPLE_DIR / data_name

    if not schema_path.exists():
        acc.add(f"Missing schema file: {schema_path}")
        return {}
    if not data_path.exists():
        acc.add(f"Missing data file: {data_path}")
        return {}

    schema = load_json(schema_path)
    data = load_json(data_path)
    validator = Draft202012Validator(schema)

    errors = sorted(validator.iter_errors(data), key=lambda err: err.path)
    for err in errors:
        dotted_path = ".".join(str(p) for p in err.path) or "<root>"
        acc.add(f"{data_name} failed schema {schema_name} at {dotted_path}: {err.message}")

    return data


def validate_cross_references(payloads: dict, acc: ValidationErrorAccumulator) -> None:
    traits = {item["id"] for item in payloads["crew_traits.json"].get("traits", [])}
    archetypes = payloads["crew_archetypes.json"].get("archetypes", [])

    for archetype in archetypes:
        for trait_id in archetype.get("trait_pool", []):
            if trait_id not in traits:
                acc.add(
                    f"crew_archetypes.json references unknown trait id '{trait_id}' in archetype '{archetype.get('id')}'"
                )

    destinations = payloads["destinations.json"].get("destinations", [])
    destination_ids = {item["id"] for item in destinations}
    for destination in destinations:
        for neighbor_id in destination.get("neighbors", []):
            if neighbor_id not in destination_ids:
                acc.add(
                    f"destinations.json has unknown neighbor id '{neighbor_id}' in destination '{destination.get('id')}'"
                )


def validate_domain_rules(payloads: dict, acc: ValidationErrorAccumulator) -> None:
    events = payloads["events.json"].get("events", [])
    for event in events:
        if event.get("weight", 0) < 0:
            acc.add(f"events.json event '{event.get('id')}' has negative weight")

    enemies = payloads["enemy_templates.json"].get("enemies", [])
    for enemy in enemies:
        profile = enemy.get("behavior_profile", {})
        for key in ["aggression", "boarding_bias"]:
            value = profile.get(key)
            if value is not None and (value < 0 or value > 1):
                acc.add(
                    f"enemy_templates.json enemy '{enemy.get('id')}' has out-of-range {key} value {value}; expected 0..1"
                )


def main() -> int:
    accumulator = ValidationErrorAccumulator()
    payloads = {}

    for schema_name, data_name in PAIRS:
        payloads[data_name] = validate_schema_pair(schema_name, data_name, accumulator)

    if any(not payloads.get(pair[1]) for pair in PAIRS):
        if accumulator.has_errors():
            print("Validation failed due to missing or invalid files:")
            accumulator.print()
            return 1

    validate_cross_references(payloads, accumulator)
    validate_domain_rules(payloads, accumulator)

    if accumulator.has_errors():
        print("Validation failed:")
        accumulator.print()
        return 1

    print("Validation passed: all schema, cross-reference, and domain checks succeeded.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
