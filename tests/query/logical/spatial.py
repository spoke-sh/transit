"""Independent rational geometry and canonical-byte oracle for the Zig library."""
from fractions import Fraction as Q
import hashlib
import json
import math
from pathlib import Path
import random
import struct
import sys
import threading

from runner import capture
from runner.paths import ROOT

SEED = 0x17002026
DEFINITION = bytes.fromhex("8e441078693f1373d69323bfeadd5cfe8c7024ec2015819bacfb2b04eaea3865")


def bits(value):
    return struct.unpack("<Q", struct.pack("<d", value))[0]


def determinant(matrix):
    """Exact Gaussian elimination; independent of Zig's translated cofactors."""
    rows = [list(map(Q, row)) for row in matrix]
    result = Q(1)
    for column in range(len(rows)):
        pivot = next((i for i in range(column, len(rows)) if rows[i][column]), None)
        if pivot is None:
            return Q(0)
        if pivot != column:
            rows[column], rows[pivot] = rows[pivot], rows[column]
            result = -result
        value = rows[column][column]
        result *= value
        for i in range(column + 1, len(rows)):
            ratio = rows[i][column] / value
            for j in range(column + 1, len(rows)):
                rows[i][j] -= ratio * rows[column][j]
    return result


def sign(points, lifted):
    rows = [list(map(Q, point)) for point in points]
    matrix = [row + ([sum(x*x for x in row)] if lifted else []) + [Q(1)] for row in rows]
    value = determinant(matrix)
    return (value > 0) - (value < 0)


def segment(points):
    a, b, c, d = [tuple(map(Q, p)) for p in points]
    sub = lambda p, q: (p[0] - q[0], p[1] - q[1])
    cross = lambda p, q: p[0]*q[1] - p[1]*q[0]
    u, v, w = sub(b, a), sub(d, c), sub(c, a)
    denominator = cross(u, v)
    if denominator:
        t, s = cross(w, v)/denominator, cross(w, u)/denominator
        if 0 < t < 1 and 0 < s < 1:
            return "cross"
        return "touch" if 0 <= t <= 1 and 0 <= s <= 1 else "disjoint"
    if a == b and c == d:
        return "touch" if a == c else "disjoint"
    direction = u if u != (0, 0) else v
    if cross(w, direction):
        return "disjoint"
    axis = 0 if direction[0] else 1
    low = max(min(a[axis], b[axis]), min(c[axis], d[axis]))
    high = min(max(a[axis], b[axis]), max(c[axis], d[axis]))
    return "disjoint" if low > high else "touch" if low == high else "overlap"


def ring_location(points, query):
    x, y = map(Q, query)
    intersections = 0
    for a, b in zip(points, points[1:]):
        if segment([a, b, query, query]) == "touch":
            return "boundary"
        ax, ay, bx, by = map(Q, (*a, *b))
        if (ay > y) != (by > y) and ax + (y-ay)*(bx-ax)/(by-ay) > x:
            intersections += 1
    return "interior" if intersections % 2 else "exterior"


def corpus():
    rng = random.Random(SEED)
    cases, expected = [], []

    def add(op, points, result, **kwargs):
        cases.append(dict(op=op, points=[[bits(x) for x in p] for p in points], **kwargs))
        expected.append(result)

    for op, dimensions, count, lifted in (("orient2d", 2, 3, False), ("orient3d", 3, 4, False),
                                           ("incircle", 2, 4, True), ("insphere", 3, 5, True)):
        for _ in range(128):
            points = [[math.ldexp(rng.choice((-1, 1)) * (1 + rng.random()), rng.randint(-100, 99))
                       for _ in range(dimensions)] for _ in range(count)]
            for candidate in (points, [points[1], points[0], *points[2:]], [points[0], points[0], *points[2:]]):
                add(op, candidate, dict(sign=sign(candidate, lifted)))
        # Maximal magnitudes exercise fixed-width overflow bounds; small
        # magnitudes exercise the opposite end of the exact coefficient range.
        for magnitude in (2.0**100, 2.0**-100, 1.0):
            points = [[rng.choice((-magnitude, 0, magnitude)) for _ in range(dimensions)] for _ in range(count)]
            add(op, points, dict(sign=sign(points, lifted)))
        for value, error in ((float("nan"), "InvalidSpatialCoordinate"), (float("inf"), "InvalidSpatialCoordinate"),
                             (math.nextafter(2.0**100, math.inf), "SpatialCoordinateRange"),
                             (math.nextafter(2.0**-100, 0), "SpatialCoordinateRange"), (5e-324, "SpatialCoordinateRange")):
            points = [[0.0]*dimensions for _ in range(count)]
            points[0][0] = value
            add(op, points, dict(error_name=error))
    # Adjacent representable inputs with nonzero exact signs behind cancellation.
    for exponent in (-100, -50, 0, 50, 99):
        x = 2.0**exponent
        points = [[x, x], [math.nextafter(x, math.inf), x], [-0.0, 0.0]]
        add("orient2d", points, dict(sign=-1, path="exact"))
    for _ in range(512):
        points = [[rng.randint(-4, 4), rng.randint(-4, 4)] for _ in range(4)]
        add("segment", points, dict(relation=segment(points)))
    # Concave simple polygons, either winding, exact endpoint/edge/random queries.
    base = [(0, 0), (8, 0), (8, 8), (4, 3), (0, 8), (0, 0)]
    for exponent in (-50, 0, 50):
        for reverse in (False, True):
            points = [[math.ldexp(x + 16, exponent), math.ldexp(y - 16, exponent)] for x, y in base]
            if reverse:
                points.reverse()
            area = sum(Q(a[0])*Q(b[1]) - Q(a[1])*Q(b[0]) for a, b in zip(points, points[1:])) / 2
            queries = points + [[math.ldexp(rng.randint(14, 26), exponent), math.ldexp(rng.randint(-18, -6), exponent)] for _ in range(40)]
            for query in queries:
                add("ring", points, dict(location=ring_location(points, query), area=float(area)), query=list(map(bits, query)))
    add("ring", [[0, 0], [2, 2], [0, 2], [2, 0], [0, 0]], dict(error_name="InvalidSpatialGeometry",
        witness=dict(reason="self_intersection", ring=0, edge=0, other_ring=None, other_edge=2)))
    add("ring", base, dict(error_name="SpatialWorkExceeded", witness=None), budget=3)
    encoded = b"SPR1" + DEFINITION + struct.pack("<IBBBBQhH", 0, 1, 1, 0, 0, 1_000_000_000, 0, 0) + bytes([1])*16
    add("reference", [], dict(encoded=list(encoded), fingerprint=list(hashlib.sha256(b"transit.spatial.reference.v1\0" + encoded).digest())))
    return cases, expected


def main():
    assert len(sys.argv) >= 2, "expected explicitly built spatial fixture binaries"
    cases, expected = corpus()
    directory = capture.directory(ROOT / ".cache/checks/spatial.json")
    inputs = directory / "inputs.json"
    inputs.write_text(json.dumps(cases) + "\n")
    report = dict(seed=SEED, **capture.provenance(ROOT), cases=len(cases), input=capture.identity(inputs), runs=[], completed=False)
    capture.write_json(directory / "spatial.json", report)
    for index, executable in enumerate(sys.argv[1:]):
        log = directory / f"kernel-{index}.log"
        stage = {}
        cancelled = threading.Event()
        timer = threading.Timer(60, cancelled.set)
        timer.start()
        try:
            capture.run([str(Path(executable).resolve()), str(inputs)], cwd=ROOT, log=log, result=stage,
                        capture_stdout=True, cancelled=cancelled)
        finally:
            timer.cancel()
            timer.join()
            report["runs"].append(stage)
            capture.write_json(directory / "spatial.json", report)
        assert stage["completed"] and stage["exit_code"] == 0, stage
        actual = [json.loads(line) for line in log.with_suffix(".stdout").read_text().splitlines()]
        assert len(actual) == len(expected), (len(actual), len(expected))
        paths = set()
        for ordinal, (got, want) in enumerate(zip(actual, expected)):
            assert got["error_name"] == want.get("error_name"), (ordinal, cases[ordinal], got, want)
            for key, value in want.items():
                observed = float(got[key]) if key == "area" else got[key]
                assert observed == value, (ordinal, cases[ordinal], key, got, want)
            if got["path"]:
                paths.add(got["path"])
        assert paths == {"interval", "exact"}, paths
    report["completed"] = True
    capture.write_json(directory / "spatial.json", report)
    print(f"spatial: {len(cases)} independent cases x {len(sys.argv)-1} builds passed; seed={SEED}; {directory}")


if __name__ == "__main__":
    main()
