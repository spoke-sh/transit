"""Shared, versioned observations for current bindings and future public SDKs."""
import json
from pathlib import Path

CATALOG = json.loads((Path(__file__).parent / "sdk.json").read_text())
assert CATALOG["version"] == 1, "Unsupported SDK conformance contract"
SCENARIOS = {scenario["id"]: scenario for scenario in CATALOG["scenarios"]}


def check(name, observed):
    """Adapters supply observations from real receipts/state or owned host work.

    Exact keys make missing observations a failure. This helper has no authority
    client, operation retry or application semantics of its own.
    """
    expected = SCENARIOS[name]["expected"]
    assert observed == expected, (name, expected, observed)
    print(f"SDK conformance v1: {name} passed", flush=True)
