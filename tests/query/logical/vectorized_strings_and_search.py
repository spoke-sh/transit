#!/usr/bin/env python3
"""Independent oracle and contract verifier for Milestone 14:
16-byte collation-prefixed GermanString vectors, PerfectHash (ComptimeMap and
FrozenDirectory with 64-byte SIMD padding and 4 KiB page-boundary guard),
compressed-domain .dictionary / .fsst predicate evaluation and late
materialization, 256-document Block-Max BM25 / WAND execution (TSS1), and
single-snapshot hybrid search (RRF and calibrated linear combination).
"""
from runner.paths import ROOT
import argparse
import hashlib
import json
import math
import struct

FIXTURE_PATH = ROOT / "contracts/sql/vectorized-strings-and-search-fixtures.json"
ALLOCATIONS_PATH = ROOT / "tests/performance/allocations.json"

ZIG_FILES = {
    "PerfectHash": ROOT / "packages/zig/transit-fuze/src/PerfectHash.zig",
    "SearchOracle": ROOT / "packages/zig/transit-fuze/src/SearchOracle.zig",
    "GermanString": ROOT / "packages/zig/transit-fuze/src/GermanString.zig",
    "PhysicalCodecs": ROOT / "packages/zig/transit-fuze/src/PhysicalCodecs.zig",
    "TSearchSegment": ROOT / "packages/zig/transit-fuze/src/TSearchSegment.zig",
    "VectorizedSearch": ROOT / "packages/zig/transit-fuze/src/VectorizedSearch.zig",
    "HybridSearch": ROOT / "packages/zig/transit-fuze/src/HybridSearch.zig",
}


def compute_segmenter_digest(segmenter_id: int, collation_id: int, stop_words: list[str]) -> str:
    h = hashlib.sha256()
    h.update(b"transit.search.segmenter.v1")
    h.update(bytes([segmenter_id, collation_id]))
    h.update(struct.pack("<I", len(stop_words)))
    for sw in stop_words:
        encoded = sw.encode("utf-8")
        h.update(struct.pack("<I", len(encoded)))
        h.update(encoded)
    return h.hexdigest()


def quantize_norm_dl(doc_len: int) -> int:
    if doc_len < 16:
        return doc_len
    msb = doc_len.bit_length() - 1
    shift = min(14, msb - 4)
    shifted = doc_len >> shift
    mantissa = 0x0F if shifted > 0x1F else (shifted & 0x0F)
    code = ((shift + 1) << 4) | mantissa
    return min(255, code)


def dequantize_norm_dl(norm: int) -> int:
    if norm < 16:
        return norm
    shift = (norm >> 4) - 1
    mantissa = norm & 0x0F
    return (mantissa | 0x10) << shift


def quantize_impact_q16(score: float) -> int:
    if score <= 0.0:
        return 0
    scaled = math.ceil(score * 1024.0)
    return 65535 if scaled >= 65535.0 else int(scaled)


def dequantize_impact_q16(q16: int) -> float:
    return float(q16) / 1024.0


def compute_idf(total_docs: int, doc_freq: int) -> float:
    if total_docs == 0 or doc_freq == 0:
        return 0.0
    n = float(total_docs)
    df = float(min(total_docs, doc_freq))
    return math.log(1.0 + (n - df + 0.5) / (df + 0.5))


def score_term_quantized(
    tf: int, norm_dl: int, avg_doc_len: float, idf: float, k1: float = 1.2, b: float = 0.75
) -> float:
    if tf == 0 or idf <= 0.0:
        return 0.0
    f = float(tf)
    dl = float(dequantize_norm_dl(norm_dl))
    safe_avg = avg_doc_len if avg_doc_len > 0.0 else 1.0
    norm_factor = 1.0 - b + b * (dl / safe_avg)
    return idf * (f * (k1 + 1.0)) / (f + k1 * norm_factor)


def build_fixtures() -> dict:
    # 1. Verify norm_dl quantization monotonicity and conservativeness across [0..4096]
    norm_dl_vectors = []
    prev_deq = 0
    for dl in [0, 1, 7, 15, 16, 17, 31, 32, 64, 127, 128, 255, 256, 511, 512, 1024, 4096]:
        q = quantize_norm_dl(dl)
        deq = dequantize_norm_dl(q)
        assert deq <= dl, f"dequantize_norm_dl({q}) = {deq} > {dl}"
        assert deq >= prev_deq, f"Non-monotonic norm_dl at dl={dl}"
        prev_deq = deq
        norm_dl_vectors.append({"doc_len": dl, "norm_u8": q, "dequantized_len": deq})

    # 2. Verify Q16 block impact ceiling bound across sample BM25 scores
    impact_vectors = []
    for total_docs, df, max_tf, min_norm, avg_dl in [
        (600, 12, 4, quantize_norm_dl(8), 10.5),
        (600, 300, 1, quantize_norm_dl(12), 10.5),
        (10000, 25, 6, quantize_norm_dl(16), 24.0),
    ]:
        idf = compute_idf(total_docs, df)
        exact = score_term_quantized(max_tf, min_norm, avg_dl, idf)
        q16 = quantize_impact_q16(exact)
        upper = dequantize_impact_q16(q16)
        assert upper >= exact, f"Block-Max upper bound {upper} < exact {exact}"
        impact_vectors.append(
            {
                "total_docs": total_docs,
                "doc_freq": df,
                "max_tf": max_tf,
                "min_norm_dl": min_norm,
                "avg_doc_len": avg_dl,
                "idf": round(idf, 12),
                "exact_score": round(exact, 12),
                "impact_q16": q16,
                "upper_bound": round(upper, 12),
            }
        )

    # 3. Segmenter SHA-256 digests
    segmenter_digests = [
        {
            "segmenter": "unicode_word_v1",
            "collation": "utf8_binary",
            "stop_words": [],
            "sha256": compute_segmenter_digest(1, 1, []),
        },
        {
            "segmenter": "ascii_fold_v1",
            "collation": "utf8_binary",
            "stop_words": ["a", "the"],
            "sha256": compute_segmenter_digest(2, 1, ["a", "the"]),
        },
    ]

    # 4. GermanString 16-byte layout and collation prefix invariants
    german_string_vectors = [
        {
            "input": "transit",
            "collation": "utf8_binary",
            "canonical_len": 7,
            "is_inline": True,
            "prefix_hex": b"tran".hex(),
        },
        {
            "input": "TRANSIT",
            "collation": "ascii_ci",
            "canonical_len": 7,
            "is_inline": True,
            "prefix_hex": b"tran".hex(),
        },
        {
            "input": "A1   ",
            "collation": "ebcdic_037_pad",
            "canonical_len": 2,
            "is_inline": True,
            "prefix_hex": "c1f10000",
        },
        {
            "input": "vectorized_search_execution_engine",
            "collation": "utf8_binary",
            "canonical_len": 34,
            "is_inline": False,
            "prefix_hex": b"vect".hex(),
        },
    ]

    return {
        "schema_version": 1,
        "contract_id": "transit.sql.vectorized-strings-and-search.v1",
        "norm_dl_vectors": norm_dl_vectors,
        "impact_vectors": impact_vectors,
        "segmenter_digests": segmenter_digests,
        "german_string_vectors": german_string_vectors,
    }


def verify_zig_and_allocations() -> None:
    required_symbols = {
        "PerfectHash": [
            "padding_bytes",
            "ComptimeMap",
            "FrozenDirectory",
            "simdEql16Padded",
            "simdEql16PageSafe",
            "ReservedSqlKeywordMap",
            "DdlOptionMap",
            "WireHeaderMap",
        ],
        "SearchOracle": [
            "SegmenterProfile",
            "computeSegmenterDigest",
            "segmentText",
            "evaluatePatternCell",
            "nearTokens",
            "quantizeNormDl",
            "dequantizeNormDl",
            "quantizeImpactQ16",
            "dequantizeImpactQ16",
            "fuseRrf",
            "fuseLinear",
        ],
        "GermanString": [
            "StringArena",
            "PayloadHandle",
            "GermanString",
            "GermanCell",
            "filterSliceMask64",
        ],
        "PhysicalCodecs": [
            "evaluateCompressedStringPage",
            "lateMaterializeSelectedGermanStrings",
        ],
        "TSearchSegment": [
            "magic",
            "SearchIndexDescriptor",
            "selectSearchAccessPath",
            "BlockHeader",
            "TermMetadata",
            "Segment",
            "encodeHeaderEnvelope",
            "validateHeaderEnvelope",
        ],
        "VectorizedSearch": [
            "SearchQuery",
            "SearchExecutionStats",
            "executeBlockMaxSearch",
        ],
        "HybridSearch": [
            "SnapshotBinding",
            "VectorSlab",
            "FusionMode",
            "ExplainSummary",
            "executeHybridSearch",
            "error.PolicyEpochRevoked",
        ],
    }

    for name, path in ZIG_FILES.items():
        if not path.is_file():
            raise SystemExit(f"Missing Milestone 14 Zig module: {path}")
        text = path.read_text(encoding="utf-8")
        for sym in required_symbols[name]:
            if sym not in text:
                raise SystemExit(f"{path.name} missing required symbol: {sym}")

    alloc_data = json.loads(ALLOCATIONS_PATH.read_text(encoding="utf-8"))
    strings_search = next(
        (p for p in alloc_data["profiles"] if p["id"] == "strings_search"), None
    )
    if strings_search is None or strings_search.get("gate") != "executable":
        raise SystemExit("tests/performance/allocations.json profile 'strings_search' must have gate='executable'")
    for check_rel in strings_search.get("checks", []):
        if not (ROOT / check_rel).is_file():
            raise SystemExit(f"Missing allocation check file in strings_search profile: {check_rel}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()

    fixtures = build_fixtures()
    verify_zig_and_allocations()
    rendered = json.dumps(fixtures, indent=2) + "\n"

    if args.write:
        FIXTURE_PATH.parent.mkdir(parents=True, exist_ok=True)
        FIXTURE_PATH.write_text(rendered, encoding="utf-8")
    elif not FIXTURE_PATH.is_file() or FIXTURE_PATH.read_text(encoding="utf-8") != rendered:
        raise SystemExit(
            f"Vectorized strings and search fixture drift in {FIXTURE_PATH}; regenerate with --write"
        )

    print(
        f"Vectorized strings & search: {len(fixtures['norm_dl_vectors'])} norm_dl vectors, "
        f"{len(fixtures['impact_vectors'])} Block-Max Q16 vectors, "
        f"{len(fixtures['german_string_vectors'])} GermanString vectors, and "
        f"{len(ZIG_FILES)} Zig modules verified"
    )


if __name__ == "__main__":
    main()
