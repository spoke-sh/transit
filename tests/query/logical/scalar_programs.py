#!/usr/bin/env python3
"""Independent Decimal results and canonical scalar instruction bytes.

Python Decimal and struct are the oracle. Zig tests compile these SQL statements,
compare canonical instruction bytes and execute pull, batch and resumed plans.
"""
import argparse
from decimal import Decimal, localcontext, ROUND_HALF_EVEN, ROUND_DOWN
import json
from runner.paths import ROOT

FIXTURE = ROOT / 'packages/zig/transit-fuze/src/fixtures/scalar-programs.json'


def fixtures():
    cases = []
    operations = {'ADD': 1, 'SUBTRACT': 2, 'MULTIPLY': 3, 'DIVIDE': 4}
    modes = {'REJECT': 0, 'HALF_EVEN': 1, 'TOWARD_ZERO': 2}
    def add(operation, a, b, result, rounding):
        ap, asc, av = a
        bp, bsc, bv = b
        precision, scale = result
        error = None
        expected = None
        with localcontext() as context:
            context.prec = 256
            x, y = Decimal(av).scaleb(-asc), Decimal(bv).scaleb(-bsc)
            if operation == 'DIVIDE' and y == 0:
                error = 'DivisionByZero'
            else:
                exact = {'ADD': lambda: x+y, 'SUBTRACT': lambda: x-y,
                         'MULTIPLY': lambda: x*y, 'DIVIDE': lambda: x/y}[operation]()
                if operation in ('ADD', 'SUBTRACT'):
                    promoted_scale = max(asc, bsc)
                    promoted_precision = min(38, max(ap-asc, bp-bsc) + promoted_scale + 1)
                    if abs(exact.scaleb(promoted_scale)) >= Decimal(10)**promoted_precision:
                        error = 'DecimalOverflow'
                coefficient = exact.scaleb(scale)
                rounded = coefficient.to_integral_value(rounding=ROUND_HALF_EVEN if rounding == 'HALF_EVEN' else ROUND_DOWN)
                if error is None and rounding == 'REJECT' and rounded != coefficient:
                    error = 'InexactDecimalRounding'
                if error is None and abs(rounded) >= Decimal(10)**precision:
                    error = 'DecimalOverflow'
                if error is None:
                    expected = str(int(rounded))
        program = bytes([3, 1, 0, 1, 1, 2, 0, 1, operations[operation], precision, scale, modes[rounding]])
        cases.append(dict(sql=f'SELECT DECIMAL_{operation}(a,b,{precision},{scale},{rounding}) AS result FROM items',
                          a_precision=ap, a_scale=asc, b_precision=bp, b_scale=bsc,
                          a=str(av), b=str(bv), expected=expected, failure=error, program_hex=program.hex()))
    for operation in operations:
        for mode in modes:
            for sign in (-1, 1):
                add(operation, (8,2,sign*125), (8,2,600), (9,1), mode)
    for operation in operations:
        add(operation, (6,3,1201), (8,1,127), (12,5), 'HALF_EVEN')
    for mode in modes:
        add('MULTIPLY', (38,38,1), (38,38,1), (38,38), mode)
        add('DIVIDE', (38,0,10**38-1), (38,38,1), (38,0), mode)
    add('ADD', (38,0,10**38-1), (38,0,1), (38,0), 'REJECT')
    add('SUBTRACT', (38,0,-(10**38-1)), (38,0,1), (38,0), 'REJECT')
    add('DIVIDE', (8,2,100), (8,2,0), (8,2), 'HALF_EVEN')
    return dict(oracle='Python Decimal at precision 256; explicit rounding; independent instruction tags', cases=cases)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--write', action='store_true')
    options = parser.parse_args()
    value = fixtures()
    encoded = json.dumps(value, indent=2) + '\n'
    if options.write:
        FIXTURE.write_text(encoded)
    if not FIXTURE.exists() or FIXTURE.read_text() != encoded:
        raise SystemExit('Scalar program oracle drift; regenerate deliberately with --write')
    print(f'Scalar program fixtures: {len(value["cases"])} independent decimal outcomes and instruction encodings checked.')


if __name__ == '__main__':
    main()
