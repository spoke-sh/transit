"""Exercise the installed static release outside the checkout, including restart."""
import json
from pathlib import Path
import shutil
import subprocess
import sys

from interfaces.installation.server import Fixture
from interfaces.cli.table_console import records

prefix = Path(sys.argv[1]).resolve()
for binary in (prefix / 'bin').iterdir():
    assert 'INTERP' not in subprocess.check_output(['readelf', '-l', str(binary)], text=True), binary
    assert '(NEEDED)' not in subprocess.check_output(['readelf', '-d', str(binary)], text=True), binary
fixture = Fixture(prefix / 'bin/transit', prefix / 'bin/transit-node', prefix / 'bin/transit-query-host')
# Exercise the single executable's embedded roles, independently of sibling files.
fixture.config['executables'] = {}
fixture.path.write_text(json.dumps(fixture.config))
passed = False
try:
    fixture.start()
    fixture.ready()
    fixture.console('CREATE TABLE release_probe (id BIGINT PRIMARY KEY);')
    fixture.console('INSERT INTO release_probe VALUES (31);')
    first = fixture.console('SELECT id FROM release_probe;')
    assert len(first) == 1 and records(first[0]) == [{'id': '31'}], first
    fixture.stop()
    fixture.start()
    fixture.ready()
    after_restart = fixture.console('SELECT id FROM release_probe;')
    assert len(after_restart) == 1 and records(after_restart[0]) == [{'id': '31'}], after_restart
    assert first[0]['complete']['rows'] == after_restart[0]['complete']['rows'] == '1'
    passed = True
finally:
    fixture.cleanup()
    if passed:
        shutil.rmtree(fixture.root)
    else:
        print(f'Private failed release installation retained at {fixture.root}', file=sys.stderr)
print('Static release: installed startup, SQL acceptance/results and retained restart passed')
