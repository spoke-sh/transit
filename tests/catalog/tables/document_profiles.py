"""Independent JSON/Expat construction and MIME field/framing oracles."""
from email.parser import BytesHeaderParser
from email.policy import compat32
import hashlib
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


def invoke(binary, family, source, chunk, binary_values=False):
    result = subprocess.run([binary, family, str(chunk), source.hex()], capture_output=True, text=True, timeout=10)
    assert result.returncode == 0, (family, source, result.stderr)
    lines = result.stdout.splitlines()
    assert lines and (lines[-1] == "complete" or lines[-1].startswith("error\t")), result.stdout
    events = []
    for line in lines[:-1]:
        kind, start, end, depth, value, detail = line.split("\t")
        start, end, depth = int(start), int(end), int(depth)
        assert 0 <= start <= end <= len(source), (line, source)
        value, detail = bytes.fromhex(value), bytes.fromhex(detail)
        if not binary_values:
            value, detail = value.decode("utf-8"), detail.decode("utf-8")
        events.append((kind, value, detail, depth, start, end))
    return lines[-1], events


def serialize(binary, source, chunk, family="json"):
    result = subprocess.run([binary, f"{family}-write", str(chunk), source.hex()],
                            capture_output=True, text=True, timeout=10)
    assert result.returncode == 0, (source, result.stderr)
    lines = result.stdout.splitlines()
    assert lines, result.stdout
    if lines[-1].startswith("error\t"):
        return None
    status, length, digest = lines[-1].split("\t")
    assert status == "complete", result.stdout
    output = bytearray()
    for line in lines[:-1]:
        label, encoded = line.split("\t")
        assert label == "bytes"
        data = bytes.fromhex(encoded)
        assert 0 < len(data) <= min(chunk, 5, 23)
        output.extend(data)
    output = bytes(output)
    assert len(output) == int(length)
    assert hashlib.sha256(output).hexdigest() == digest
    return output


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


def mime_oracle(binary):
    rng = random.Random(1604)
    corpus = [([], b""), ([], bytes(range(256))),
              ([(b"X-Test", b" first\r\n\tsecond  "), (b"x-test", b"")], b"\x00\xff\r\n")]
    names = [b"X-Test", b"x-test", b"Content-Type", b"MIME-Version",
             b"Content-Transfer-Encoding", b"[X]"]
    values = [b"", b"  ", b"\tfirst\r\n second", b" =?utf-8?Q?opaque?=",
              b" multipart/mixed;\r\n\tboundary=opaque", b" base64", b" 1.0",
              b" one\r\n\t two \r\n three", b"a\t b  "]
    for _ in range(160):
        fields = [(rng.choice(names), rng.choice(values)) for _ in range(rng.randrange(9))]
        body = bytes(rng.randrange(256) for _ in range(rng.randrange(129)))
        corpus.append((fields, body))
    schedules = 0
    for fields, body in corpus:
        header = bytearray()
        expected = []
        for name, value in fields:
            raw = name + b":" + value
            expected.append(("mime_field", name, value.replace(b"\r\n", b""),
                             0, len(header), len(header) + len(raw)))
            header.extend(raw + b"\r\n")
        expected.append(("mime_headers_end", b"", b"", 0, len(header), len(header) + 2))
        source = bytes(header) + b"\r\n" + body
        body_start = len(header) + 2
        # Python owns independent header splitting, case/order and duplicate
        # preservation. Exact whitespace and raw spans additionally use the
        # generated field inputs above; no expected value comes from Zig.
        parsed = BytesHeaderParser(policy=compat32).parsebytes(source)
        assert not parsed.defects, parsed.defects
        reference = [(name.encode("ascii"), value.replace("\r\n", "").lstrip(" \t").encode("ascii"))
                     for name, value in parsed.raw_items()]
        assert reference == [(name, value.replace(b"\r\n", b"").lstrip(b" \t")) for name, value in fields]
        for chunk in (1, 3, 17, 8192):
            for mode in ("mime", "mime-candidate"):
                status, events = invoke(binary, mode, source, chunk, binary_values=True)
                assert status == "complete", (source, status)
                assert events[:len(expected)] == expected, (source, events, expected)
                observed = bytearray()
                offset = body_start
                for kind, value, detail, depth, start, end in events[len(expected):]:
                    assert (kind, detail, depth, start) == ("mime_body", b"", 0, offset)
                    assert 0 < len(value) <= min(chunk, 7, 1024)
                    assert source[start:end] == value
                    observed.extend(value)
                    offset = end
                assert bytes(observed) == body and offset == len(source)
                schedules += 1
        # A complete header prefix with its separator cut short must never
        # certify the frame. The stdlib's permissive recovery is not our oracle.
        for mode in ("mime", "mime-candidate"):
            status, _ = invoke(binary, mode, source[:body_start - 1], 3, binary_values=True)
            assert status.startswith("error\t"), (source, status)
            schedules += 1
    # Explicit refusals for the declared CRLF/ASCII framing subset. MIME field
    # semantics and arbitrary binary body bytes are separate from these checks.
    negatives = [b"X: a\n\n", b"X: a\rb\r\n\r\n", b"X: a\r\n\rx",
                 b" orphan\r\n\r\n", b": empty\r\n\r\n", b"X : bad\r\n\r\n",
                 b"X: \x00\r\n\r\n", b"X: \x7f\r\n\r\n", b"X: \xff\r\n\r\n",
                 b"X\r\n\r\n", b"X:" + b"a" * 997 + b"\r\n\r\n"]
    for source in negatives:
        for chunk in (1, 8192):
            for mode in ("mime", "mime-candidate"):
                status, _ = invoke(binary, mode, source, chunk, binary_values=True)
                assert status.startswith("error\t"), (source, status)
                schedules += 1
    print(f"MIME entity framing: {schedules} independent field/order, binary-body, span and refusal schedules passed")


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
                for mode in (family, f"{family}-candidate"):
                    status, events = invoke(binary, mode, source, chunk)
                    assert status == "complete", (mode, source, status)
                    actual = [event[:4] for event in events]
                    assert (actual if family == "json" else coalesce(actual)) == expected, (mode, source, actual, expected)
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
    constructed = 0
    for source in json_sources:
        expected = list(json_events(json.loads(source, object_pairs_hook=Pairs, parse_int=Number, parse_float=Number)))
        canonical = None
        for chunk in (1, 3, 17, 8192):
            encoded = serialize(binary, source, chunk)
            assert encoded is not None
            actual = list(json_events(json.loads(encoded, object_pairs_hook=Pairs, parse_int=Number, parse_float=Number)))
            assert actual == expected, (source, encoded, expected, actual)
            if canonical is None:
                canonical = encoded
            assert encoded == canonical, (source, chunk)
            constructed += 1
    xml_constructed = 0
    for source in xml_sources:
        expected = xml_events(source)
        canonical = None
        for chunk in (1, 3, 17, 8192):
            encoded = serialize(binary, source, chunk, "xml")
            assert encoded is not None
            assert xml_events(encoded) == expected, (source, encoded, expected, xml_events(encoded))
            if canonical is None:
                canonical = encoded
            assert encoded == canonical, (source, chunk)
            xml_constructed += 1
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
                for mode in (family, f"{family}-candidate"):
                    status, _ = invoke(binary, mode, source, chunk)
                    assert status.startswith("error\t"), (mode, source, status)
                    schedules += 1
                assert serialize(binary, source, chunk, family) is None, source
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
                    for mode in (family, f"{family}-candidate"):
                        status, _ = invoke(binary, mode, source, chunk)
                        assert status.startswith("error\t"), (mode, source, status)
                        schedules += 1
                    assert serialize(binary, source, chunk, family) is None, source
                invalid_mutations += 1
    assert invalid_mutations >= 300, invalid_mutations
    print(f"Document construction: {constructed} JSON and {xml_constructed} XML independent round trips and byte commitments passed")
    print(f"Document profiles: {schedules} independent JSON/Expat reader/candidate schedules, values, order, provenance and malformed-frame refusals passed")
    mime_oracle(binary)


if __name__ == "__main__":
    main()
