"""Exact SQL/maps/diagnostic parity; executable identity is deliberately separate."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
IDENTITY_FIELDS = {'compiler_revision', 'compiler_digest', 'input_digest'}


def invoke(binary, directory, *args, expected=0):
    result = subprocess.run([str(binary), 'build', '--format', 'json', '--color', 'off', *args],
                            cwd=directory, env={'PATH': os.defpath, 'NO_COLOR': '1'},
                            capture_output=True, text=True, timeout=120)
    assert result.returncode == expected and not result.stderr, (binary, args, result)
    return json.loads(result.stdout)


def artifacts(binary, workspace, destination):
    invoke(binary, workspace, '--out', str(destination))
    sql = (destination / 'application.sql').read_bytes()
    provenance = json.loads((destination / 'provenance.json').read_bytes())
    assert provenance['complete'] is True
    return sql, provenance


def compare(upstream, compiler):
    count = 0
    with tempfile.TemporaryDirectory(prefix='transitc-parity-') as temporary:
        root = Path(temporary).resolve()
        for name in ('application-build', 'application-typed-targets', 'application-queue-programs',
                     'application-typed-queue', 'application-modular-programs'):
            workspace = root / name
            shutil.copytree(ROOT / 'tests/fixtures' / name, workspace)
            for path in workspace.rglob('*'):
                path.chmod(0o700 if path.is_dir() else 0o600)
            old_sql, old = artifacts(upstream, workspace, root / (name + '-upstream'))
            new_sql, new = artifacts(compiler, workspace, root / (name + '-compiler'))
            repeated_sql, repeated = artifacts(compiler, workspace, root / (name + '-repeat'))
            assert old_sql == new_sql == repeated_sql == (workspace / 'expected.sql').read_bytes(), name
            assert new == repeated, (name, 'nondeterministic provenance')
            assert old.keys() == new.keys()
            assert {k: v for k, v in old.items() if k not in IDENTITY_FIELDS} == {k: v for k, v in new.items() if k not in IDENTITY_FIELDS}, name
            assert old['compiler_digest'] != new['compiler_digest']
            assert old['input_digest'] != new['input_digest']
            count += 1
        # Use one identical path for both invocations, including path-bearing facts.
        workspace = root / 'invalid'
        workspace.mkdir()
        negatives = [
            (None, [], 'application.source.entry'),
            ('CREATE TARGET default AS BEGIN SELECT ; END;', [], 'application.source.syntax'),
            ('CREATE TARGET default AS BEGIN CREATE PUBLIC TABLE t (id BIGINT); END;', ['--target', 'absent'], 'application.source.target'),
            ("IMPORT missing FROM 'missing.transit'; CREATE TARGET default AS BEGIN END;", [], 'application.source.import'),
        ]
        for source, options, code in negatives:
            if source is not None:
                (workspace / 'build.transit').write_text(source)
            old = invoke(upstream, workspace, *options, expected=1)
            new = invoke(compiler, workspace, *options, expected=1)
            assert old == new, (old, new)
            assert old['code'] == code, old
            assert not (workspace / '.transit/build').exists()
            count += 1
    print(f'PASS {count} upstream/transitc parity cases; only {sorted(IDENTITY_FIELDS)} differ')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--transit', default=os.environ.get('TRANSIT_UPSTREAM_BIN'), required='TRANSIT_UPSTREAM_BIN' not in os.environ)
    parser.add_argument('--transitc', default='zig-out/bin/transitc')
    args = parser.parse_args()
    compare(Path(args.transit).resolve(), Path(args.transitc).resolve())
