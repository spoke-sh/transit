"""Exercise the installed static release outside the checkout, including restart."""
import ctypes
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

from interfaces.installation.server_board import Board
from interfaces.installation.board_workbench import installed as workbench
from interfaces.cli.table_console import records
from interfaces.cli.console_terminal import local_transcript
from interfaces.cli.console_edit import local_edit

def run(prefix):
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    prefix = Path(prefix).resolve()
    for binary in (prefix / 'bin').iterdir():
        assert 'INTERP' not in subprocess.check_output(['readelf', '-l', str(binary)], text=True), binary
        assert '(NEEDED)' not in subprocess.check_output(['readelf', '-d', str(binary)], text=True), binary
    fixture = Board(prefix / 'bin/transit', prefix / 'bin/transit-node',
                    prefix / 'bin/transit-query-host', prefix / 'bin/transit-board')
    # Exercise the single executable's embedded roles, independently of sibling files.
    fixture.config['executables'] = {}
    fixture.path.write_text(json.dumps(fixture.config))
    passed = False
    try:
        fixture.start()
        fixture.ready()
        # Default Board is an inspection view; all frontend assets come from the executable.
        html = fixture.request('/').decode()
        assets = re.findall(r'(?:src|href)="([^"]+\.(?:js|css))"', html)
        assert assets and all(path.startswith('/') and not path.startswith('//') for path in assets), assets
        for path in assets:
            assert len(fixture.request(path)) > 0, path
        atlas = fixture.atlas()
        assert atlas['identity']['permissions'] == 16, atlas
        assert not json.loads(fixture.request('/api/v1/capabilities'))['query_enabled']
        local_transcript(fixture.cli, fixture.root, env={'PATH': '/unavailable'})
        local_edit(fixture.cli, fixture.root, env={'PATH': '/unavailable'})
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
        fixture.console('INSERT INTO release_probe VALUES (32);')
        original = fixture.record()['registration']
        # The fixture is a subreaper; stop(kill=True) requires every owned
        # child to die and be joined before another manager can start.
        fixture.stop(kill=True)
        fixture.start()
        fixture.ready()
        recovered = fixture.console('SELECT id FROM release_probe;')
        assert len(recovered) == 1 and sorted(records(recovered[0]), key=lambda row: row['id']) == [
            {'id': '31'}, {'id': '32'}], recovered
        assert recovered[0]['complete']['rows'] == '2'
        replacement = fixture.record()['registration']
        assert replacement['pid'] == original['pid'] and replacement['generation'] > original['generation']
        passed = True
    finally:
        fixture.cleanup()
        if passed:
            shutil.rmtree(fixture.root)
        else:
            print(f'Private failed release installation retained at {fixture.root}', file=sys.stderr)
    print('Static release: embedded Board, terminal/editor, SQL results, retained restart and supervisor-death recovery passed')
    workbench(prefix)


if __name__ == '__main__':
    run(sys.argv[1])
