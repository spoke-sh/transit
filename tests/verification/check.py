"""Validate proof ownership and reviewed limit classifications without a deployment."""
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
DIRECTORY = Path(__file__).resolve().parent


def read(name):
    value = json.loads((DIRECTORY / name).read_text())
    assert value["version"] == 1, f"unsupported {name}"
    return value


def validate(suite, invariants, limits):
    tasks = [task for lane in suite["lanes"].values() for task in lane]
    assert len(tasks) == len(set(tasks)), "duplicate CI task ownership"
    for tier, lanes in suite["tiers"].items():
        assert lanes and len(lanes) == len(set(lanes)), tier
        assert set(lanes) <= suite["lanes"].keys(), tier
    tasks += [task for group in suite["external_tasks"].values() for task in group]
    for parent, children in suite["nested_tasks"].items():
        assert parent in tasks and children, parent
        tasks += children
    for task in tasks:
        parts = task.split("::")
        path = ROOT / ("justfile" if len(parts) == 1 else "tasks/" + "/".join(parts[:-1]) + ".just")
        # Nested launcher recipes live under tasks/launchers/.
        assert path.is_file(), f"missing task owner: {task}: {path}"
        assert re.search(r"^" + re.escape(parts[-1]) + r"(?:\s[^\n]*)?:", path.read_text(), re.M), task
    identifiers = set()
    for item in invariants["invariants"]:
        assert item["id"] not in identifiers, f"duplicate invariant: {item['id']}"
        identifiers.add(item["id"])
        for field in ("claim", "profile", "scenarios", "limits", "tasks", "implementation"):
            assert item[field], (item["id"], field)
        assert set(item["tasks"]) <= set(tasks), item["id"]
        for path in [item["owner"], *item["implementation"]]:
            assert (ROOT / path).is_file(), (item["id"], path)
        if item["model"] is not None:
            assert (ROOT / item["model"]).is_file(), item["id"]
    seen = set()
    for item in limits["limits"]:
        key = item["source"], item["symbol"]
        assert key not in seen, key
        seen.add(key)
        assert item["classification"] in {
            "total-cardinality", "operation", "working-set", "encoding", "quota-ceiling",
        }, key
        expression = re.search(r"pub const " + re.escape(item["symbol"]) +
                               r"(?:\s*:\s*\w+)?\s*=\s*([^;]+);", (ROOT / item["source"]).read_text())
        assert expression and expression[1] == item["expression"], f"review changed bound: {key}"
    # New max_* constants in these critical profiles need an explicit review.
    for source in {item["source"] for item in limits["limits"]}:
        for symbol in re.findall(r"pub const (max_\w+)(?:\s*:.*?)?\s*=", (ROOT / source).read_text()):
            assert (source, symbol) in seen, f"unclassified bound: {source}:{symbol}"
    for item in limits["identities"]:
        assert item["anchor"] in (ROOT / item["source"]).read_text(), item


def main():
    suite, invariants, limits = [read(name) for name in ("suite.json", "invariants.json", "limits.json")]
    validate(suite, invariants, limits)
    # Fail closed on lost ownership or silently changed implementation ceilings.
    import copy
    broken = copy.deepcopy(suite)
    broken["lanes"]["core"].append("test::missing-proof")
    try:
        validate(broken, invariants, limits)
    except AssertionError:
        pass
    else:
        raise AssertionError("unowned proof passed")
    broken = copy.deepcopy(limits)
    broken["limits"][0]["expression"] = "unreviewed change"
    try:
        validate(suite, invariants, broken)
    except AssertionError:
        pass
    else:
        raise AssertionError("limit drift passed")
    print(f"Verification catalog: {len(invariants['invariants'])} invariants, "
          f"{len(limits['limits'])} classified bounds and all task owners checked.")


if __name__ == "__main__":
    main()
