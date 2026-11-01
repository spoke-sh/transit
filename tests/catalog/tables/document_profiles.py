"""Compare the pure Zig parsers with Python JSON and Expat, including raw spans."""
import json
from pathlib import Path
import random
import subprocess
import sys
from xml.parsers import expat


class Pairs(list):
    pass


class Number(str):
    pass


def invoke(binary, family, source, chunk):
    result = subprocess.run([binary, family, str(chunk), source.hex()], capture_output=True, text=True, timeout=10)
    assert result.returncode == 0, (family, source, result.stderr)
    lines = result.stdout.splitlines()
    assert lines and (lines[-1] == "complete" or lines[-1].startswith("error\t")), result.stdout
    events = []
    for line in lines[:-1]:
        kind, start, end, depth, value, detail = line.split("\t")
        start, end, depth = int(start), int(end), int(depth)
        assert 0 <= start <= end <= len(source), (line, source)
        events.append((kind, bytes.fromhex(value).decode("utf-8"), bytes.fromhex(detail).decode("utf-8"), depth, start, end))
    return lines[-1], events


def json_events(value, depth=0):
    if isinstance(value, Pairs):
        yield "object_start", "", "", depth
        for key, child in value:
            yield "key", key, "", depth + 1
            yield from json_events(child, depth + 1)
        yield "object_end", "", "", depth
    elif isinstance(value, list):
        yield "array_start", "", "", depth
        for child in value:
            yield from json_events(child, depth + 1)
        yield "array_end", "", "", depth
    elif isinstance(value, Number):
        yield "number", str(value), "", depth
    elif isinstance(value, str):
        yield "string", value, "", depth
    elif value is None:
        yield "null_value", "null", "", depth
    elif isinstance(value, bool):
        yield "boolean", "true" if value else "false", "", depth
    else:
        raise AssertionError(value)


def xml_events(source):
    parser = expat.ParserCreate()
    parser.ordered_attributes = True
    depth = 0
    events = []
    def start(name, attributes):
        nonlocal depth
        events.append(("element_start", name, "", depth))
        depth += 1
        for index in range(0, len(attributes), 2):
            events.append(("attribute", attributes[index], attributes[index + 1], depth))
    def end(name):
        nonlocal depth
        depth -= 1
        events.append(("element_end", name, "", depth))
    def text(value):
        if depth and value:
            events.append(("text", value, "", depth))
    parser.StartElementHandler = start
    parser.EndElementHandler = end
    parser.CharacterDataHandler = text
    parser.CommentHandler = lambda value: events.append(("comment", value, "", depth))
    parser.ProcessingInstructionHandler = lambda name, body: events.append(("processing_instruction", name, body, depth))
    parser.Parse(source, True)
    return coalesce(events)


def coalesce(events):
    result = []
    for kind, value, detail, depth in events:
        if kind == "text" and not value:
            continue
        if kind == "text" and result and result[-1][0] == "text" and result[-1][3] == depth:
            previous = result.pop()
            value = previous[1] + value
        result.append((kind, value, detail, depth))
    return result


def random_json(rng, depth=0):
    if depth > 3 or rng.randrange(3) == 0:
        return rng.choice(["null", "true", "false", "-0", "1.2300e+021", "9007199254740993",
                           json.dumps(rng.choice(["", "a\x00b", "é🙂", "a\n\r\t\\\"", "\u2028"]), ensure_ascii=bool(rng.randrange(2)))])
    if rng.randrange(2):
        return "[" + ", ".join(random_json(rng, depth + 1) for _ in range(rng.randrange(5))) + "]"
    return "{" + ",".join(json.dumps(rng.choice(["a", "a", "é"])) + ":" + random_json(rng, depth + 1) for _ in range(rng.randrange(5))) + "}"


def random_xml(rng, depth=0):
    name = rng.choice(["root", "item", "_a-b.c"])
    attributes = "".join(f" a{i}='{rng.choice(['', 'é🙂', '&quot;&apos;&amp;', '&#10; x  y', 'line&#13;'])}'" for i in range(rng.randrange(4)))
    if depth > 3 or rng.randrange(3) == 0:
        return f"<{name}{attributes}/>"
    body = "".join(random_xml(rng, depth + 1) if rng.randrange(2) else rng.choice([
        "é🙂&#x20;", "left\r\nright", "<!-- comment -->", "<![CDATA[<literal>&\r\n]]>", "<?step data?>", "&lt;&gt;&amp;&#x1f642;",
    ]) for _ in range(rng.randrange(4)))
    return f"<{name}{attributes}>{body}</{name}>"


def main():
    assert len(sys.argv) == 2, "expected exact parser probe binary"
    binary = str(Path(sys.argv[1]).resolve())
    rng = random.Random(1601)
    json_sources = [b'{"a":1,"a":2}', b'"\\ud834\\udd1e"', b'1e9999999', b' -0 \r\n']
    json_sources.extend(random_json(rng).encode() for _ in range(160))
    xml_sources = [b"<?xml version='1.0' encoding='UTF-8'?><r/>", b"<!-- before --><r><?p?>a<![CDATA[b]]>c</r><!-- after -->"]
    xml_sources.extend(random_xml(rng).encode() for _ in range(160))
    schedules = 0
    for family, sources in (("json", json_sources), ("xml", xml_sources)):
        for source in sources:
            expected = list(json_events(json.loads(source, object_pairs_hook=Pairs, parse_int=Number, parse_float=Number))) if family == "json" else xml_events(source)
            for chunk in (1, 3, 17, 8192):
                status, events = invoke(binary, family, source, chunk)
                assert status == "complete", (family, source, status)
                actual = [event[:4] for event in events]
                assert (actual if family == "json" else coalesce(actual)) == expected, (family, source, actual, expected)
                if family == "json":
                    for kind, value, _, _, start, end in events:
                        raw = source[start:end]
                        if kind in ("key", "string"):
                            assert json.loads(raw) == value, (source, start, end, value)
                        elif kind in ("number", "boolean", "null_value"):
                            assert raw.decode() == value
                        else:
                            assert raw == {"object_start": b"{", "object_end": b"}", "array_start": b"[", "array_end": b"]"}[kind]
                schedules += 1
    # These are invalid in the standards, not merely outside the qualified subset.
    negatives = {
        "json": [b"[1,]", b"01", b"true false", b'"\\x"', b'"\xc0\x80"', b"1.", b"{"],
        "xml": [b"<r><s></r>", b"<r/><s/>", b"<r a='1' a='2'/>", b"<r>&#0;</r>", b"<r>]]></r>", b"<r>\xc0\x80</r>", b"<!--a--b--><r/>"]}
    for family, sources in negatives.items():
        for source in sources:
            try:
                json.loads(source) if family == "json" else expat.ParserCreate().Parse(source, True)
            except (ValueError, expat.ExpatError):
                pass
            else:
                raise AssertionError(("bad independent negative", family, source))
            for chunk in (1, 8192):
                status, _ = invoke(binary, family, source, chunk)
                assert status.startswith("error\t"), (family, source, status)
                schedules += 1
    # Mutate a deterministic subset; oracle-invalid bytes must never complete.
    # Valid mutations are covered by the value/order corpus above, avoiding a
    # false full-XML claim for namespace/non-ASCII-name mutations.
    invalid_mutations = 0
    for family, sources in (("json", json_sources), ("xml", xml_sources)):
        for _ in range(250):
            source = bytearray(rng.choice(sources))
            index = rng.randrange(len(source) + 1)
            if index < len(source) and rng.randrange(2):
                del source[index]
            else:
                source[index:index] = bytes([rng.randrange(256)])
            source = bytes(source)
            try:
                json.loads(source) if family == "json" else expat.ParserCreate().Parse(source, True)
            except (ValueError, expat.ExpatError):
                for chunk in (1, 8192):
                    status, _ = invoke(binary, family, source, chunk)
                    assert status.startswith("error\t"), (family, source, status)
                    schedules += 1
                invalid_mutations += 1
    assert invalid_mutations >= 300, invalid_mutations
    print(f"Document profiles: {schedules} independent JSON/Expat chunk schedules, values, order, provenance and malformed-frame refusals passed")


if __name__ == "__main__":
    main()
