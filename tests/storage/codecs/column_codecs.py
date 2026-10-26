#!/usr/bin/env python3
"""Independent physical column fixtures: Python CP037 and exact rational HFP.

No Transit codec is imported. CP037's full 256-character repertoire follows
Unicode's CP037 table version 2.00 (1996-04-24); the runtime records its source.
"""
from runner.paths import ROOT
import argparse
from fractions import Fraction
import json
import math
from pathlib import Path
import struct

FIXTURE = ROOT / 'packages/zig/transit-fuze/src/fixtures/column-codecs.json'


def hfp(value):
    sign = int(math.copysign(1, value) < 0) << 63
    if value == 0:
        return sign.to_bytes(8, 'big')
    exact = Fraction.from_float(abs(value))
    for characteristic in range(128):
        exponent = characteristic - 64
        fraction = exact / Fraction(16) ** exponent
        if Fraction(1, 16) <= fraction < 1:
            bits = fraction * (1 << 56)
            assert bits.denominator == 1
            return (sign | characteristic << 56 | bits.numerator).to_bytes(8, 'big')
    raise ValueError('outside normalized HFP range')


def fixtures():
    definition = bytes.fromhex(json.loads((ROOT / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition'])
    logical = ''.join(chr(i) for i in range(256))
    cp037 = logical.encode('cp037')
    assert sorted(cp037) == list(range(256))
    floats = [0., -0., 1., -125.5, .1, math.ldexp(1., -260), math.nextafter(math.ldexp(1., 252), 0.)]
    floats += [math.ldexp(1.125, exp) for exp in range(-259, 252, 17)]
    pages = []
    for encoding, tag, width in [('comp', 5, 8), ('comp_3', 6, 16), ('zoned', 7, 31)]:
        for value in [-(1 << 63), -12345, 0, 12345, (1 << 63)-1]:
            if encoding == 'comp':
                data = value.to_bytes(width, 'big', signed=True)
            elif encoding == 'comp_3':
                digits = str(abs(value)).zfill(31)
                data = bytes.fromhex(digits + ('d' if value < 0 else 'c'))
            else:
                data = bytearray(int(digit) | 0xf0 for digit in str(abs(value)).zfill(width))
                data[-1] = (data[-1] & 15) | (0xd0 if value < 0 else 0xc0)
            pages.append(dict(encoding=encoding, value=str(value), page=(b'TCP1'+definition+bytes([tag])+struct.pack('<I',1)+b'\0'+data).hex()))
    return dict(cp037=cp037.hex(), utf8=logical.encode().hex(),
                floats=[dict(ieee=struct.pack('>d', v).hex(), hfp=hfp(v).hex()) for v in floats], pages=pages)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    expected = json.dumps(fixtures(), indent=2) + '\n'
    if args.write:
        FIXTURE.write_text(expected)
    else:
        assert FIXTURE.read_text() == expected, 'column codec fixtures are stale'
    print('Physical column fixtures: complete CP037, exact rational HFP and signed mainframe page bytes passed')


if __name__ == '__main__':
    main()
