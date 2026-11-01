"""Independent runtime oracle for lossless string Batch and encoded Table pages.

Python byte ordering/case folding and its CP037 codec supply expectations.
This executes a build-owned Zig binary; the static fixture checker is separate.
"""
import json
from pathlib import Path
import random
import sys
from runner import capture
from runner.paths import ROOT


def key(value, collation):
    if collation == "ebcdic_cp037":
        return value.encode("cp037")
    encoded = value.encode("utf-8")
    return encoded.lower() if collation == "ascii_ci" else encoded


def cases():
    rng = random.Random(14)
    values = ["", "\x00", "A", "a", "A ", "a\x00", "éÖa", "ABCDEFGHIJKL",
              "ABCDEFGHIJKLM", "same-prefix-aa", "same-prefix-ab", "MiXeD  "]
    values += ["".join(rng.choice("aAzZ09 éÖ\x00") for _ in range(n))
               for n in (4, 11, 12, 13, 31, 64)]
    result = []
    for collation in ("utf8_binary", "ascii_ci", "ebcdic_cp037"):
        for encoding in ("dictionary", "fsst"):
            for op in ("eq", "ne", "lt", "le", "gt", "ge"):
                for literal in ("", "a", "A ", "ABCDEFGHIJKL", "same-prefix-ab", "éÖa"):
                    rows = [dict(state="value", value=value) for value in values]
                    rows += [dict(state=state) for state in ("null", "missing", "type_error", "conflict")]
                    result.append(dict(id=len(result), collation=collation, encoding=encoding,
                                       op=op, literal=literal, rows=rows))
            result.append(dict(id=len(result), collation=collation, encoding=encoding,
                               op="gt", literal="a", rows=[dict(state="value", value="Long Spelling " * 600)]))
    return result


def expected(case):
    outcomes = []
    target = key(case["literal"], case["collation"])
    for row in case["rows"]:
        state = row["state"]
        if state != "value":
            outcomes.append("unknown" if state in ("null", "missing") else state)
            continue
        source = key(row["value"], case["collation"])
        order = (source > target) - (source < target)
        selected = dict(eq=order == 0, ne=order != 0, lt=order < 0, le=order <= 0,
                        gt=order > 0, ge=order >= 0)[case["op"]]
        outcomes.append("yes" if selected else "no")
    return outcomes


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: string_execution.py BUILD_OWNED_BINARY")
    binary = str(Path(sys.argv[1]).resolve())
    run_dir = capture.directory(ROOT / ".cache/verification/string-execution/latest.json")
    corpus = cases()
    source = run_dir / "cases.json"
    source.write_text(json.dumps(corpus), encoding="utf-8")
    record = dict(capture.provenance(ROOT), completed=False, cases=len(corpus), seed=14)
    capture.write_json(run_dir / "oracle.json", record)
    execution = {}
    try:
        process = capture.run([binary, str(source)], cwd=ROOT, log=run_dir / "execution.log",
                              result=execution, capture_stdout=True)
        process.check_returncode()
        actual = [json.loads(line) for line in process.stdout.splitlines()]
        assert len(actual) == len(corpus), "incomplete oracle output"
        for case, result in zip(corpus, actual, strict=True):
            assert result["id"] == case["id"], (case["id"], "sequence")
            wanted = expected(case)
            for path in ("batch", "physical"):
                assert result[path] == wanted, (case, path, result[path], wanted)
            raw = [row.get("value") for row in case["rows"]]
            assert result["raw"] == raw, (case["id"], "lossy projection")
            selected = [row["value"] for row, outcome in zip(case["rows"], wanted, strict=True) if outcome == "yes"]
            assert result["selected"] == selected, (case["id"], "late projection")
            if case["encoding"] == "fsst" and case["collation"] != "ebcdic_cp037":
                assert result["streamed"] == sum(row["state"] == "value" for row in case["rows"])
                assert result["materialized"] == 0
        record["completed"] = True
        record["rows"] = sum(len(case["rows"]) for case in corpus)
        print(f"String execution: {len(corpus)} cases / {record['rows']} rows passed Batch, physical outcomes and lossless projections; evidence {run_dir}")
    finally:
        record["execution"] = execution
        capture.write_json(run_dir / "oracle.json", record)


if __name__ == "__main__":
    main()
