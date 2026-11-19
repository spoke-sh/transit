"""Run the runtime owner's complete application-test schedule through transitc."""
import hashlib
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]


def main():
    compiler = Path(sys.argv[1] if len(sys.argv) > 1 else 'zig-out/bin/transitc').resolve()
    runtime = Path(os.environ['TRANSIT_TEST_RUNTIME']).resolve()
    source = Path(os.environ['TRANSIT_TEST_SOURCE']).resolve()
    # Runtime fixture ownership remains in the pinned runtime source. The
    # compiler CLI and its child host both run with network access denied by the
    # original schedule, including PATH/configuration denial and exact failures.
    sys.path.insert(0, str(source / 'tests'))
    from harness import phases
    recorder = phases.Recorder(ROOT)
    phases.recorder = lambda: recorder
    from interfaces.cli import application_test as suite
    original_oracle = suite.installed_oracle
    suite.installed_oracle = lambda _compiler, sql: original_oracle(runtime, sql)
    original_invoke = suite.invoke
    digest = list(hashlib.sha256(runtime.read_bytes()).digest())
    version = subprocess.run([str(runtime), '--version'], capture_output=True, text=True, check=True).stdout
    revision = version.split('(git ', 1)[1].split(';', 1)[0]

    def invoke(*args, **kwargs):
        report = original_invoke(*args, **kwargs)
        if report.get('runtime') is not None:
            assert report['runtime'] == {'revision': revision, 'executable_digest': digest}, report['runtime']
        return report

    suite.invoke = invoke
    sys.argv = [str(source / 'tests/interfaces/cli/application_test.py'), str(compiler)]
    suite.main()
    print('PASS transitc test: complete native application schedule, offline cases, failures, limits, cleanup and runtime identity')


if __name__ == '__main__':
    main()
