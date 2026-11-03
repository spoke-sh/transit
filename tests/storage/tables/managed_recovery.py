"""Named finite-computation handoffs, killed after acceptance and before reply.

This is process-death evidence, not power-loss evidence. The proxy observes public
requests and responses; it neither edits accepted work nor drives storage internals.
"""
import base64
import json
import threading


CASES = (
    "work-record", "head-claim", "work-binding", "acquired-cut", "result-page",
    "output-staged", "output-executed", "revision-manifest", "checkpoint-executed",
    "preparing", "committed", "cleanup-complete", "work-complete", "empty-complete",
    "abort-saved", "abort-decided",
)


class Boundary:
    def __init__(self, name, profile):
        assert name in CASES, name
        self.name = name
        self.profile = profile
        self.active = False
        self.reached = threading.Event()
        self.release = threading.Event()
        self.original = None
        self.cut = None
        self.checkpoint_sequence = None
        self.aborting = None
        self.calls = 0

    def save(self, suffix, value):
        self.profile.with_name(self.profile.name + suffix).write_text(json.dumps(value))

    def observe(self, envelope, status, data):
        """True withholds this reply. The driver must kill both processes first."""
        self.calls += 1
        if status != 200 or not isinstance(envelope.get("action"), dict):
            return False
        action = envelope["action"]
        result = json.loads(data)["result"]
        if not isinstance(result, dict):
            return False
        record = action.get("record", {})
        staged = record.get("stage", {})
        work_record = None
        if staged.get("format") == 0x44465731:
            work_record = json.loads(base64.b64decode(staged["bytes"]["base64"], validate=True))
            reference = result["record"]["reference"]
            if self.original is None:
                assert work_record["phase"] == "acquiring", work_record["phase"]
                self.original = dict(reference=reference, work=work_record)
                self.save(".managed-original", self.original)
            if work_record["phase"] == "aborting":
                self.aborting = reference
        transaction = action.get("transaction", {})
        tx_result = result.get("transaction", {})
        if "acquire" in transaction:
            cut = tx_result["acquired"]["cut"]
            if self.cut is None:
                self.cut = cut
                self.save(".managed-cut", cut)
            else:
                assert cut == self.cut, "Recovery replaced the accepted source cut"
        if "stage_kv" in transaction:
            self.checkpoint_sequence = transaction["stage_kv"]["sequence"]
        if not self.active or self.reached.is_set() or self.original is None:
            return False

        work = self.original["work"]
        owned = record.get("stage_transaction", {})
        bind = action.get("client_token", {}).get("bind", {})
        update = action.get("client_progress", {}).get("update", {})
        mutation = action.get("kv", {}).get("mutate", {})
        statement = transaction.get("statement", {})
        settlement = tx_result.get("status", {}) if "settle" in transaction else {}
        observation = settlement.get("observation", {})
        decided = observation.get("decided", {}) if isinstance(observation, dict) else {}
        matched = {
            "work-record": work_record is not None and work_record["phase"] == "acquiring",
            "head-claim": mutation.get("binding", {}).get("target") == work["lease"]["target"]["object"],
            "work-binding": bind.get("key") == work["previous"]["pending"],
            "acquired-cut": "acquire" in transaction,
            "result-page": owned.get("format") == 0xC4465031,
            "output-staged": "stage" in transaction,
            "output-executed": bool(statement) and statement["request"]["statement"]["sequence"] == 2,
            "revision-manifest": owned.get("format") == 0xC4465231,
            "checkpoint-executed": bool(statement) and self.checkpoint_sequence is not None
                and statement["request"]["statement"]["sequence"] == self.checkpoint_sequence,
            "preparing": isinstance(observation, dict) and "preparing" in observation,
            "committed": decided.get("outcome") == "committed" and not settlement["cleanup_complete"],
            "cleanup-complete": decided.get("outcome") == "committed" and settlement["cleanup_complete"],
            "work-complete": update.get("key") == work["previous"]["pending"] and update.get("pending") is False,
            "empty-complete": update.get("key") == work["previous"]["pending"] and update.get("pending") is False,
            "abort-saved": self.aborting is not None and update.get("record") == self.aborting,
            "abort-decided": decided.get("outcome") == "aborted",
        }[self.name]
        if not matched:
            return False
        self.save(".managed-interrupted-request", envelope)
        self.save(".managed-interrupted-response", json.loads(data))
        self.reached.set()
        # This thread owns only the proxy response. Bounded driver deadlines and
        # finally blocks release it even if either process exits unexpectedly.
        self.release.wait()
        return True
