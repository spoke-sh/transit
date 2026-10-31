"""Timing gates require comparable complete evidence and never add nested time twice."""
import io
import json
import unittest
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile

from ci_cost import archive_report, evaluate
from feedback_cost import partition


class FeedbackCost(unittest.TestCase):
    def test_nested_and_parallel_phases_partition_elapsed_time(self):
        rows = [dict(kind='schedule', started_unix=0, seconds=100),
                dict(kind='consumer-install', started_unix=10, seconds=40),
                dict(kind='consumer-build', started_unix=15, seconds=20),
                dict(kind='build-graph', started_unix=60, seconds=20),
                dict(kind='artifact-import', started_unix=90, seconds=0),
                dict(kind='teardown', started_unix=99)]
        self.assertEqual(partition(rows), {'schedule': 40, 'consumer-install': 20,
                                          'consumer-build': 20, 'build-graph': 20})
        self.assertEqual(sum(partition(rows).values()), 100)

    def test_scope_cache_hardware_and_failed_runs_cannot_establish_regression(self):
        baseline = dict(run_id=1, status='measured', inventory={'sha256':'scope'}, cache_profile='warm',
                        feedback_seconds=100, aggregate_runner_seconds=200,
                        lanes=[dict(name='core', runner_labels=['ubuntu-24.04'])])
        budgets = dict(targets=dict(inventory=baseline['inventory'],feedback_seconds=150,aggregate_runner_seconds=300),
                       regressions=dict(minimum_samples=3, relative=.15, absolute_seconds=30))
        history = [baseline | {'run_id': index} for index in (3, 2, 1)]
        current = baseline | dict(run_id=4, feedback_seconds=140)
        candidate = evaluate(current.copy(), budgets, history)
        self.assertEqual(len(candidate['regressions']), 1)
        self.assertFalse(candidate['regression_confirmed'])
        self.assertTrue(candidate['target_met'])
        confirmed = evaluate(current | {'run_id':5}, budgets, [candidate, *history])
        self.assertTrue(confirmed['regression_confirmed'])
        for change in (dict(status='inconclusive'), dict(inventory={'sha256':'other'}),
                       dict(cache_profile='cold'), dict(lanes=[dict(name='core', runner_labels=['other-host'])])):
            result = evaluate(current | change, budgets, history)
            self.assertFalse(result['regressions'])
        small = evaluate(current | dict(feedback_seconds=125), budgets, history)
        self.assertFalse(small['regressions'])

    def test_real_benchmark_runner_isolates_edits_and_retains_failed_prefix(self):
        owner = Path(__file__).resolve().parent
        for fail in (False, True):
            with self.subTest(fail=fail), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                source = root / 'source'
                (source / 'tests/runner').mkdir(parents=True)
                for name in ('build_feedback.py', 'capture.py'):
                    (source / 'tests/runner' / name).write_bytes((owner / name).read_bytes())
                for name in ('sdks/rust/transit-client/src/lib.rs', 'packages/zig/transit-client/src/root.zig'):
                    path = source / name
                    path.parent.mkdir(parents=True)
                    path.write_text('// original\n')
                (source / '.gitignore').write_text('.cache/\n')
                subprocess.run(['git', 'init', '-q', source], check=True)
                subprocess.run(['git', 'add', '.'], cwd=source, check=True)
                subprocess.run(['git', '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                                'commit', '-qm', 'test(ci): fixture'], cwd=source, check=True)
                fake = root / 'nix'
                fake.write_text(f'#!{sys.executable}\nimport sys\nfrom pathlib import Path\n'
                    'if "ci::dependencies" in sys.argv: sys.exit(0)\n'
                    'marker=Path(".cache/count"); marker.parent.mkdir(exist_ok=True)\n'
                    'count=int(marker.read_text())+1 if marker.exists() else 1\n'
                    'marker.write_text(str(count))\n'
                    'sdk="mutation" in Path("sdks/rust/transit-client/src/lib.rs").read_text()\n'
                    'native="mutation" in Path("packages/zig/transit-client/src/root.zig").read_text()\n'
                    'assert (sdk,native) == {1:(False,False),2:(False,False),3:(True,False),4:(False,True)}[count]\n'
                    f'sys.exit(23 if {fail!r} and count == 2 else 0)\n')
                fake.chmod(0o700)
                result = subprocess.run([sys.executable, '-B', source / 'tests/runner/build_feedback.py',
                                         '--work-root', root], cwd=source, capture_output=True,
                                        env=os.environ | {'PATH':str(root)+os.pathsep+os.environ['PATH']})
                reports = list((source / '.cache/build-feedback').glob('*/report.json'))
                self.assertEqual(len(reports), 1, result.stderr)
                report = json.loads(reports[0].read_text())
                self.assertEqual(report['completed'], not fail)
                self.assertEqual(result.returncode == 0, not fail, result.stderr)
                self.assertEqual(len(report['cases']), 2 if fail else 4)
                self.assertEqual(Path(report['work_directory']).exists(), fail)
                if fail:
                    self.assertEqual(report['cases'][-1]['exit_code'], 23)
                    self.assertFalse(report['cases'][-1]['warm_target_met'])
                self.assertEqual(subprocess.check_output(['git','status','--porcelain'],cwd=source), b'')

    def test_only_bounded_single_json_artifacts_are_read(self):
        def archive(contents):
            output = io.BytesIO()
            with zipfile.ZipFile(output, 'w') as stream:
                for name, data in contents:
                    stream.writestr(name, data)
            return output.getvalue()
        self.assertEqual(archive_report(archive([('report.json','{"version":1}')])), {'version':1})
        for files in ([('script.py','print("wrong")')], [('report.json','{"version":99}')],
                      [('report.json',' ' * 2_000_001)], [('a.json','{}'),('b.json','{}')]):
            with self.subTest(files=[name for name, _ in files]), self.assertRaises(AssertionError):
                archive_report(archive(files))


if __name__ == '__main__':
    unittest.main()
