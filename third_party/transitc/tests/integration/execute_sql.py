"""Execute transitc's emitted SQL with the separately pinned real Transit host."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def main():
    upstream = Path(os.environ['TRANSIT_UPSTREAM_BIN']).resolve()
    compiler = Path(sys.argv[1] if len(sys.argv) > 1 else 'zig-out/bin/transitc').resolve()
    # These runtime fixtures stay with their owning, frozen runtime repository.
    # The import path is local to this process and never exported to children.
    sys.path.insert(0, str(Path(os.environ['TRANSIT_UPSTREAM_SOURCE']) / 'tests'))
    from harness import phases
    recorder = phases.Recorder(ROOT)
    phases.recorder = lambda: recorder
    from interfaces.installation.server import Fixture
    from interfaces.cli.table_console import records
    with tempfile.TemporaryDirectory(prefix='transitc-execute-') as temporary:
        root = Path(temporary).resolve()
        workspace = root / 'source'
        shutil.copytree(ROOT / 'tests/integration/fixtures/application', workspace)
        for path in workspace.rglob('*'):
            path.chmod(0o700 if path.is_dir() else 0o600)
        # The runtime installation provisions its own `items` table. Compile a
        # separate declared identity so the proof does not replace bootstrap data.
        entry = workspace / 'build.transit'
        entry.write_text(entry.read_text().replace('items', 'compiled_items'))
        output = root / 'artifact'
        result = subprocess.run([str(compiler), 'build', '--out', str(output), '--format', 'json'],
                                cwd=workspace, capture_output=True, text=True, timeout=120, check=True)
        assert json.loads(result.stdout)['ok'] is True
        sql = (output / 'application.sql').read_text()
        assert sql == (ROOT / 'tests/integration/fixtures/expected.sql').read_text().replace('items', 'compiled_items').replace('ITEMS', 'COMPILED_ITEMS')
        shutil.rmtree(workspace)
        fixture = Fixture(upstream, parent="/var/tmp")
        passed = False
        try:
            fixture.use_private_runtime()
            fixture.start()
            fixture.ready()
            outcomes = fixture.console(sql)
            rows = [records(outcome) for outcome in outcomes if 'schema' in outcome]
            assert rows == [[{'id': '8', 'value': 'initial'}]], rows
            fixture.stop()
            fixture.start()
            fixture.ready()
            assert records(fixture.console('SELECT * FROM compiled_items;')[-1]) == rows[0]
            passed = True
        finally:
            fixture.cleanup()
            if passed:
                shutil.rmtree(fixture.root)
            else:
                print(f'Private runtime failure evidence retained at {fixture.root}', file=sys.stderr)
    print('PASS transitc SQL executed source-free by pinned Transit, with terminal row coverage and retained restart')


if __name__ == '__main__': main()
