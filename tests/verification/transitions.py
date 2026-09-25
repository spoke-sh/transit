"""Generated schedules against real Zig transitions with a small independent oracle."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
CORPUS = Path(__file__).resolve().parent / "corpus"


class Model:
    """Single PID, one worker principal; commit is a compared journal append.

    This is deliberately not a second implementation of the full kernel. The
    projection tracks only mailbox progress, caller results and fencing/retry.
    """
    def __init__(self):
        self.state = dict(position=4, owner=1, generation=1, revision=0,
                          admitted=0, consumed=0, cancelled=0, lifecycle="running",
                          value=0, permissions=255, sequence=0)
        self.inputs = []
        self.prepared = {}
        self.receipts = {}

    def step(self, action):
        s = self.state
        kind, slot = action["kind"], action.get("slot", 0)
        failure = receipt = None
        if kind == "send":
            if s["lifecycle"] != "running":
                failure = "RetiredProcess"
            else:
                self.inputs.append(s["position"])
                s["admitted"] += 1
                receipt = s["position"]
                s["position"] += 1
        elif kind in {"revoke", "grant"}:
            s["permissions"] = 0 if kind == "revoke" else 255
            receipt = s["position"]
            s["position"] += 1
        elif kind == "own":
            if s["lifecycle"] != "running":
                failure = "RetiredProcess"
            elif action.get("owner", 1) == 1 and not s["permissions"]:
                failure = "Forbidden"
            else:
                s["owner"] = action.get("owner", 1)
                s["generation"] += 1
                receipt = s["position"]
                s["position"] += 1
        elif kind == "terminate":
            if s["lifecycle"] != "running":
                failure = "RetiredProcess"
            else:
                receipt = s["position"]
                s.update(lifecycle="terminated", owner=None,
                         cancelled=s["admitted"] - s["consumed"], position=s["position"] + 1)
        elif kind == "prepare":
            self.prepared.pop(slot, None)
            if s["consumed"] + s["cancelled"] == len(self.inputs):
                failure = "NoInput"
            elif not s["permissions"]:
                failure = "Forbidden"
            elif s["owner"] != 1 or action.get("stale_generation", False):
                failure = "StaleGeneration"
            elif action.get("stale_revision", False):
                failure = "StaleState"
            else:
                self.prepared[slot] = dict(position=s["position"],
                    sequence=s["sequence"] + 1, generation=s["generation"],
                    revision=s["revision"], input=self.inputs[s["consumed"]],
                    value=action.get("value", 1))
        elif kind in {"commit", "retry"}:
            candidate = self.prepared.get(slot)
            if candidate is None:
                failure = "NoPreparation"
            elif kind == "commit":
                if action.get("fault") == "before_append":
                    failure = "StorageUnavailable"
                elif candidate["position"] != s["position"]:
                    failure = "Conflict"
                else:
                    receipt = self.publish(candidate)
                    if action.get("fault") == "after_append":
                        failure, receipt = "LostAcknowledgement", None
            elif not s["permissions"]:
                failure = "Forbidden"
            elif candidate["sequence"] in self.receipts:
                previous, at = self.receipts[candidate["sequence"]]
                # A retried signed request contains no prepared tail. Its
                # canonical bytes depend on sequence/generation/input/revision.
                fields = ("sequence", "generation", "input", "revision", "value")
                if all(candidate[field] == previous[field] for field in fields):
                    receipt = at
                else:
                    failure = "ConflictingRetry"
            elif candidate["sequence"] != s["sequence"] + 1:
                failure = "SequenceGap"
            elif s["lifecycle"] != "running":
                failure = "RetiredProcess"
            elif candidate["generation"] != s["generation"] or s["owner"] != 1:
                failure = "StaleGeneration"
            elif candidate["revision"] != s["revision"]:
                failure = "StaleState"
            elif s["consumed"] == len(self.inputs) or candidate["input"] != self.inputs[s["consumed"]]:
                failure = "InvalidInput"
            else:
                receipt = self.publish(candidate)
        elif kind not in {"restart", "clock"}:
            raise ValueError(f"unmodeled action {kind}")
        return dict(s, failure=failure, receipt=receipt)

    def publish(self, candidate):
        s = self.state
        receipt = s["position"]
        s.update(consumed=s["consumed"] + 1, value=candidate["value"],
                 revision=receipt, sequence=candidate["sequence"], position=receipt + 1)
        self.receipts[candidate["sequence"]] = (copy.copy(candidate), receipt)
        return receipt


class ResourceModel(Model):
    """One retained KV value and one captured view, independent of engine pages.

    Time belongs to validation, not publication: an unchanged prepared tail can
    still win after its view deadline. A retry requiring fresh validation cannot.
    """
    def __init__(self):
        super().__init__()
        self.state.update(position=8, generation=2, resource_revision=3,
                          resource_value=None, resource_permissions=7,
                          view=None, time_floor=0)
        self.now = dict(unix_ms=10, error_ms=0)
        self.view = None

    def time_error(self):
        if self.now.get("error_ms", 0) > 2:
            return "UntrustedTime"
        if self.now["unix_ms"] < self.state["time_floor"]:
            return "ClockRollback"

    def deadline_error(self, deadline, expired):
        now, uncertainty = self.now["unix_ms"], self.now.get("error_ms", 0)
        if max(0, now - uncertainty) >= deadline:
            return expired
        if now + uncertainty >= deadline:
            return "DeadlineUncertain"

    def validate(self, candidate):
        s, view = self.state, self.view
        if not s["permissions"]:
            return "Forbidden"
        if failure := self.time_error():
            return failure
        if view is None or candidate["view"] != view["id"]:
            return "StateViewExpired"
        if any(candidate[field] != view[field] for field in ("generation", "revision", "input")):
            return "InvalidStateView"
        if failure := self.deadline_error(view["deadline"], "StateViewExpired"):
            return failure
        if s["resource_permissions"] != 7:
            return "Forbidden"
        if view["resource_revision"] != s["resource_revision"]:
            return "StaleStateResource"
        if s["lifecycle"] != "running":
            return "RetiredProcess"
        if s["owner"] != 1 or candidate["generation"] != s["generation"]:
            return "StaleGeneration"
        if candidate["revision"] != s["revision"]:
            return "StaleState"
        if s["consumed"] == len(self.inputs) or candidate["input"] != self.inputs[s["consumed"]]:
            return "InvalidInput"

    def step(self, action):
        s = self.state
        kind, slot = action["kind"], action.get("slot", 0)
        failure = receipt = None
        if kind == "clock":
            self.now = action.get("time", dict(unix_ms=10))
        elif kind == "resource_grant":
            s["resource_permissions"] = action.get("resource_permissions", 7)
            receipt = s["position"]
            s["position"] += 1
        elif kind == "close_view":
            if self.view is None:
                failure = "NoView"
            else:
                self.view = s["view"] = None
                receipt = s["position"]
                s["position"] += 1
        elif kind == "open_view":
            deadline = action.get("deadline_ms", 50)
            if s["consumed"] + s["cancelled"] == len(self.inputs):
                failure = "NoInput"
            elif not s["permissions"] or s["resource_permissions"] & 3 != 3:
                failure = "Forbidden"
            elif failure := self.time_error():
                pass
            elif s["owner"] != 1:
                failure = "StaleGeneration"
            elif deadline > max(0, self.now["unix_ms"] - self.now.get("error_ms", 0)) + 60000:
                failure = "InvalidLifetime"
            elif failure := self.deadline_error(deadline, "DeadlineExpired"):
                pass
            elif self.view is not None:
                failure = "StateViewInUse"
            else:
                receipt = s["position"]
                self.view = dict(id=receipt, deadline=deadline, generation=s["generation"],
                                 revision=s["revision"], input=self.inputs[s["consumed"]],
                                 resource_revision=s["resource_revision"])
                s.update(view=receipt, position=receipt + 1, sequence=s["sequence"] + 1,
                         time_floor=self.now["unix_ms"])
                self.receipts[s["sequence"]] = (None, receipt)
        elif kind == "prepare":
            self.prepared.pop(slot, None)
            if s["consumed"] + s["cancelled"] == len(self.inputs):
                failure = "NoInput"
            elif self.view is None:
                failure = "NoView"
            else:
                candidate = dict(position=s["position"], sequence=s["sequence"] + 1,
                    generation=s["generation"] + int(action.get("stale_generation", False)),
                    revision=s["revision"] + int(action.get("stale_revision", False)),
                    input=self.inputs[s["consumed"]], value=action.get("value", 1),
                    view=self.view["id"], time=self.now["unix_ms"])
                failure = self.validate(candidate)
                if failure is None:
                    self.prepared[slot] = candidate
        elif kind == "retry":
            candidate = self.prepared.get(slot)
            if candidate is None:
                failure = "NoPreparation"
            elif not s["permissions"]:
                failure = "Forbidden"
            elif candidate["sequence"] in self.receipts:
                previous, at = self.receipts[candidate["sequence"]]
                fields = ("sequence", "generation", "revision", "input", "value", "view")
                if previous is None or any(candidate[f] != previous[f] for f in fields):
                    failure = "ConflictingRetry"
                elif s["resource_permissions"] != 7:
                    failure = "Forbidden"
                else:
                    receipt = at
            elif failure := self.validate(candidate):
                pass
            else:
                receipt = self.publish(dict(candidate, time=self.now["unix_ms"]))
        else:
            result = super().step(action)
            if kind in {"revoke", "grant"}:
                s["resource_permissions"] = 0
                result["resource_permissions"] = 0
            if kind in {"own", "terminate"} and result["failure"] is None:
                self.view = s["view"] = result["view"] = None
            return result
        return dict(s, failure=failure, receipt=receipt)

    def publish(self, candidate):
        receipt = super().publish(candidate)
        self.view = None
        self.state.update(resource_value=candidate["value"], resource_revision=receipt,
                          view=None, time_floor=candidate["time"])
        return receipt


def generated(seed, count, resource=False):
    # Owned xorshift64 sequence: a Python/runtime upgrade cannot silently change
    # seed interpretation. The actual trace is also persisted on failure.
    state = seed or 1
    def draw(size):
        nonlocal state
        state ^= (state << 13) & ((1 << 64) - 1)
        state ^= state >> 7
        state ^= (state << 17) & ((1 << 64) - 1)
        return state % size
    actions = [{"kind": "send"}]
    choices = ("send", "send", "prepare", "prepare", "commit", "commit", "retry",
               "own", "revoke", "grant", "restart")
    if resource:
        choices += ("open_view", "open_view", "close_view", "resource_grant", "clock")
        actions.append({"kind": "open_view"})
    for _ in range(count):
        kind = choices[draw(len(choices))]
        action = {"kind": kind}
        if kind in {"prepare", "commit", "retry"}:
            action["slot"] = draw(4)
        if kind == "prepare":
            action.update(value=draw(10000), stale_generation=draw(8) == 0,
                          stale_revision=draw(8) == 0)
        if kind == "commit":
            action["fault"] = ("none", "none", "before_append", "after_append")[draw(4)]
        if kind == "own":
            action["owner"] = draw(2)
        if kind == "resource_grant":
            action["resource_permissions"] = (0, 3, 7)[draw(3)]
        if kind == "clock":
            action["time"] = dict(unix_ms=(0, 10, 49, 50, 51, 100)[draw(6)],
                                  error_ms=draw(4))
        if kind == "open_view":
            action["deadline_ms"] = (50, 100, 200)[draw(3)]
        actions.append(action)
    return {"version": 1, "seed": seed,
            "profile": "resource" if resource else "inline_state", "actions": actions}


def compare(trace, lines):
    assert len(lines) == len(trace["actions"]), "incomplete trace output"
    model = ResourceModel() if trace.get("profile") == "resource" else Model()
    for index, (action, actual) in enumerate(zip(trace["actions"], lines)):
        assert actual["index"] == index, "missing/reordered observation"
        expected = model.step(action)
        observed = {name: actual[name] for name in expected}
        if observed != expected:
            return {"index": index, "action": action, "expected": expected, "actual": observed}
    return None


def minimize(actions, fails, budget=96):
    """Bounded delta debugging; preserve the property failure, not exact indices."""
    current, granularity, attempts = list(actions), 2, 0
    while len(current) > 1 and attempts < budget:
        chunk = max(1, (len(current) + granularity - 1) // granularity)
        reduced = False
        for start in range(0, len(current), chunk):
            candidate = current[:start] + current[start + chunk:]
            if not candidate:
                continue
            attempts += 1
            if fails(candidate):
                current, granularity, reduced = candidate, max(2, granularity - 1), True
                break
            if attempts >= budget:
                break
        if not reduced:
            if granularity >= len(current):
                break
            granularity = min(len(current), granularity * 2)
    return current


def run(binary, traces, directory):
    paths = []
    for i, trace in enumerate(traces):
        path = directory / f"trace-{i}.json"
        path.write_text(json.dumps(trace) + "\n")
        paths.append(path)
    result = subprocess.run([binary, *map(str, paths)], capture_output=True, text=True, timeout=90)
    grouped = {str(path): [] for path in paths}
    for line in result.stdout.splitlines():
        value = json.loads(line)
        grouped[value["trace"]].append(value)
    failures = []
    for path, trace in zip(paths, traces):
        lines = grouped[str(path)]
        if result.returncode and len(lines) != len(trace["actions"]):
            failures.append({"driver_exit": result.returncode, "stderr": result.stderr[-8192:]})
        else:
            failures.append(compare(trace, lines))
    if result.returncode and not any(failures):
        # A failure during teardown is also evidence, even if every observation
        # was already emitted. Never turn a nonzero exit into a passing trace.
        failures[-1] = {"driver_exit": result.returncode, "stderr": result.stderr[-8192:]}
    return failures


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary")
    parser.add_argument("--seeds", type=int, default=16)
    parser.add_argument("--steps", type=int, default=48)
    parser.add_argument("--trace", type=Path)
    args = parser.parse_args()
    assert 0 < args.seeds <= 10000 and 0 < args.steps < 4096
    traces = ([json.loads(args.trace.read_text())] if args.trace else
              [json.loads(path.read_text()) for path in sorted(CORPUS.glob("*.json"))] +
              [generated(seed, args.steps, resource) for resource in (False, True)
               for seed in range(1, args.seeds + 1)])
    started = time.monotonic()
    with tempfile.TemporaryDirectory(prefix="transit-properties-") as directory:
        directory = Path(directory)
        try:
            failures = []
            for start in range(0, len(traces), 16):
                failures += run(args.binary, traces[start:start + 16], directory)
        except (subprocess.TimeoutExpired, ValueError, AssertionError) as failure:
            destination = ROOT / ".cache/verification/transitions/inconclusive"
            destination.mkdir(parents=True, exist_ok=True)
            for i, trace in enumerate(traces):
                (destination / f"trace-{i}.json").write_text(json.dumps(trace, indent=2) + "\n")
            raise SystemExit(f"Incomplete property run ({failure}); traces retained at {destination}")
        for trace, failure in zip(traces, failures):
            if failure is None:
                continue
            small = dict(trace)
            small["actions"] = minimize(trace["actions"], lambda actions: run(
                args.binary, [dict(trace, actions=actions)], directory)[0] is not None)
            destination = ROOT / ".cache/verification/transitions"
            destination.mkdir(parents=True, exist_ok=True)
            (destination / "failure.json").write_text(json.dumps(small, indent=2) + "\n")
            (destination / "original.json").write_text(json.dumps(trace, indent=2) + "\n")
            difference = run(args.binary, [small], directory)[0]
            (destination / "difference.json").write_text(json.dumps(difference, indent=2) + "\n")
            raise SystemExit(f"Transition invariant failed; minimized replay at {destination / 'failure.json'}")
    # Validate the minimizer itself against a schedule-dependent defect.
    assert minimize(list(range(20)), lambda values: 3 in values and 14 in values) == [3, 14]
    evidence = {"version": 1, "profile": "single PID/caller; authority/retry and captured KV views",
                "passed": True, "traces": len(traces),
                "generators": ["xorshift64-v1", "xorshift64-resource-v1"],
                "revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                "dirty": bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT)),
                "binary_sha256": hashlib.sha256(Path(args.binary).read_bytes()).hexdigest(),
                "steps": sum(len(trace["actions"]) for trace in traces),
                "seconds": round(time.monotonic() - started, 3)}
    destination = ROOT / ".cache/verification"
    destination.mkdir(parents=True, exist_ok=True)
    (destination / "transitions.json").write_text(json.dumps(evidence, indent=2) + "\n")
    print(f"Transition properties passed: {evidence}")


if __name__ == "__main__":
    main()
