#!/usr/bin/env python3
"""Compile reviewed caller cause names into the test driver, never production."""
import json
from pathlib import Path
import re
import sys


def main():
    manifest = json.loads(Path(sys.argv[1]).read_text())
    output = ''
    for identity, name in [('query-caller', 'query_caller'), ('direct-catalog-caller', 'catalog_caller'), ('board-inspection', 'board_inspection')]:
        boundary, = [value for value in manifest['boundaries'] if value['id'] == identity]
        causes = sorted(boundary['codes'])
        assert causes and all(re.fullmatch(r'[A-Za-z_][A-Za-z_0-9]*', cause) for cause in causes)
        output += 'pub const ' + name + ' = [_]anyerror{\n' + ''.join('    error.' + cause + ',\n' for cause in causes) + '};\n'
    Path(sys.argv[2]).write_text(output)


if __name__ == '__main__':
    main()
