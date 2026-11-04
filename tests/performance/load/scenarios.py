"""Installed product journeys, with independent results and stage latency records."""
import argparse
from contextlib import contextmanager
import ctypes
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import time

from interfaces.installation.server import Fixture
from interfaces.sql_sessions.local import Client
from interfaces.sql_sessions.storage import text
from performance.console.statements import verify_table
from performance.load.installed import DRIVERS, Recorder, digest, host_limits, process_snapshot, read
from performance.load.report import UNAVAILABLE
from performance.mutations.mutation_latency import Console
from runner.capture import directory, provenance
from runner.paths import ROOT


class Journey:
    def __init__(self, fixture, recorder):
        self.fixture, self.recorder = fixture, recorder
        connection = fixture.console_config()
        path = fixture.root / 'scenario-console.json'
        path.write_text(json.dumps(connection))
        path.chmod(0o600)
        self.shell = Console(fixture, config=path, mode='table')
        self.observer = Client(connection, fixture.record()['definition']).open()
        self.counts = {}

    def close(self):
        try:
            self.shell.close()
        finally:
            self.observer.close()

    @contextmanager
    def sample(self, case):
        index = self.counts.get(case, 0)
        self.counts[case] = index + 1
        with self.recorder.sample(case, index, self.fixture) as record:
            yield record

    def elapsed(self, case, began, **fields):
        index = self.counts.get(case, 0)
        self.counts[case] = index + 1
        self.recorder.emit(dict(phase='sample', case=case, index=index, outcome='complete', verified=True,
                                elapsed_ns=time.perf_counter_ns() - began, **fields))

    def command(self, case, sql, counts=None):
        with self.sample(case) as record:
            output, measured = self.shell.call(sql)
            expected = 'Statement completed.'
            if counts is not None:
                expected += f' Matched {counts[0]}; changed {counts[1]}.'
            assert output == expected + '\n', output
            record.update(verified=True, **measured)

    def rows(self, case, sql, expected):
        with self.sample(case) as record:
            output, measured = self.shell.call(sql)
            verify_table(output, expected)
            record.update(verified=True, rows=len(expected), **measured)

    def head(self, name):
        values = read(self.observer, f'SHOW DATAFLOW {name}', 1)
        assert len(values) == 1 and len(values[0]) == 1
        return json.loads(text(values[0][0]))['observation']['head']

    def settle(self, name, revision, table, expected, case, foreground=None):
        # The original finite observation budget is independent of a latency
        # gate. A complete but late result is retained and fails that gate.
        deadline = time.monotonic() + 180
        with self.sample(case) as sample:
            polls = 0
            while True:
                assert time.monotonic() < deadline and polls < 2000, 'dataflow completion deadline'
                observed = self.head(name)
                polls += 1
                assert observed['blocked'] == 'none', observed
                if foreground is not None:
                    self.rows('console_during_dataflow', 'SELECT * FROM items;', foreground)
                if observed['revision'] >= revision and observed['pending'] is None:
                    self.rows('derived_result', f'SELECT * FROM {table};', expected)
                    assert observed['rows'] == len(expected), observed
                    assert time.monotonic() < deadline, 'late dataflow verification'
                    sample.update(verified=True, revision=observed['revision'], rows=len(expected), polls=polls)
                    return observed['revision']
                time.sleep(.05)


def console(journey, repeat):
    journey.rows('console_cold', 'SELECT * FROM items;', [])
    for index in range(repeat):
        journey.rows('console_warm_empty', 'SELECT * FROM items;', [])
        journey.command('console_insert', 'INSERT INTO items (id, value) VALUES (1, 10);', (1, 1))
        journey.rows('console_after_insert', 'SELECT * FROM items;', [(1, 10)])
        journey.rows('console_warm_one', 'SELECT * FROM items;', [(1, 10)])
        journey.command('console_update', 'UPDATE items SET value = 20 WHERE id = 1;', (1, 1))
        journey.rows('console_after_update', 'SELECT * FROM items;', [(1, 20)])
        journey.command('console_noop', 'UPDATE items SET value = 20 WHERE id = 1;', (1, 0))
        journey.command('console_delete', 'DELETE FROM items WHERE id = 1;', (1, 1))
        journey.rows('console_after_delete', 'SELECT * FROM items;', [])
        journey.command('console_zero_match', 'DELETE FROM items WHERE id = 1;', (0, 0))


def dataflow(journey, repeat):
    journey.command('setup', 'CREATE TABLE scenario_output (id BIGINT PRIMARY KEY, value BIGINT);', (0, 0))
    journey.command('setup', 'CREATE DATAFLOW scenario_projection INTO scenario_output AS SELECT id, value FROM items;')
    journey.command('setup', 'AUTHORIZE DATAFLOW scenario_projection;')
    journey.command('setup', 'ACTIVATE DATAFLOW scenario_projection;')
    revision = journey.settle('scenario_projection', 1, 'scenario_output', [], 'dataflow_initial', [])
    for index in range(repeat):
        journey.command('source_insert', 'INSERT INTO items VALUES (1, 10);', (1, 1))
        revision = journey.settle('scenario_projection', revision + 1, 'scenario_output', [(1, 10)],
                                  'dataflow_after_insert', [(1, 10)])
        journey.command('source_update', 'UPDATE items SET value = 20 WHERE id = 1;', (1, 1))
        revision = journey.settle('scenario_projection', revision + 1, 'scenario_output', [(1, 20)],
                                  'dataflow_after_update', [(1, 20)])
        journey.command('source_delete', 'DELETE FROM items WHERE id = 1;', (1, 1))
        revision = journey.settle('scenario_projection', revision + 1, 'scenario_output', [],
                                  'dataflow_after_delete', [])
    with journey.sample('dataflow_idle') as sample:
        time.sleep(1)
        assert journey.head('scenario_projection')['revision'] == revision
        sample.update(verified=True, revision=revision)
    journey.command('setup', 'RETIRE DATAFLOW scenario_projection;')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('cli', 'http_caller', 'http_worker'):
        parser.add_argument('--' + name.replace('_', '-'), type=Path, required=name == 'cli')
    parser.add_argument('--scenario', choices=('console', 'dataflow', 'webhook', 'all'), default='all')
    parser.add_argument('--repeat', type=int, choices=range(1, 101), default=1, metavar='1..100')
    parser.add_argument('--binary-revision')
    parser.add_argument('--budgets', type=Path)
    args = parser.parse_args()
    if args.binary_revision is not None and (len(args.binary_revision) != 40
            or any(c not in '0123456789abcdef' for c in args.binary_revision)):
        parser.error('--binary-revision must be the full committed Git revision')
    if args.scenario in ('webhook', 'all') and (args.http_caller is None or args.http_worker is None):
        parser.error('the webhook scenario requires --http-caller and --http-worker')
    budgets = json.loads(args.budgets.read_text()) if args.budgets else None
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    evidence = directory(ROOT / '.cache/performance/scenarios/campaign.json') / 'observations.jsonl'
    print(f'Scenario evidence: {evidence}', file=sys.stderr, flush=True)
    fixture, journey, success = None, None, False
    retained = None
    with evidence.open('x') as output:
        recorder = Recorder(output)
        recorder.emit(dict(phase='campaign', outcome='started'))
        try:
            fixture = Fixture(args.cli, args.cli, args.cli)
            fixture.use_private_runtime()
            # Exercise the default embedded node/SQL/Board composition. Artifact
            # inputs remain explicit; no sibling executable discovery is needed.
            fixture.config.pop('executables')
            fixture.no_ui = False
            fixture.config['board'] = dict(port=fixture.reserve_port())
            fixture.config['applications'] = dict(port=fixture.reserve_port())
            fixture.path.write_text(json.dumps(fixture.config))
            binaries = dict(cli=fixture.cli)
            for role in ('http_caller', 'http_worker'):
                if getattr(args, role) is None:
                    continue
                path = fixture.root / 'bin' / role
                path.parent.mkdir(mode=0o700, exist_ok=True)
                shutil.copy2(getattr(args, role), path)
                binaries[role] = str(path)
            version = subprocess.check_output([fixture.cli, '--version'], text=True).strip()
            if args.binary_revision:
                assert args.binary_revision in version and 'dirty' not in version
            recorder.emit(dict(phase='manifest', scenario=args.scenario, repeat=args.repeat,
                budgets=budgets,
                source=provenance(ROOT), binary_revision=args.binary_revision, cli_version=version,
                binaries={role: digest(path) for role, path in binaries.items()},
                drivers={name: digest(ROOT/'tests'/name) for name in (*DRIVERS,
                    'performance/load/scenarios.py', 'performance/load/scenario_report.py',
                    'performance/mutations/mutation_latency.py', 'performance/console/statements.py',
                    'interfaces/installation/webhook.py', 'interfaces/installation/server_application_faults.py',
                    'interfaces/http/serving.py')},
                host_id=digest('/proc/sys/kernel/random/boot_id'), storage_device=fixture.root.stat().st_dev,
                system=platform.platform(), cpus=os.cpu_count(), load=os.getloadavg(),
                host_limits=host_limits(fixture.root), toolchain=subprocess.check_output(['zig', 'version'], text=True).strip(),
                durability='native-local synchronous', maintenance='enabled', build_mode='ReleaseSafe',
                cache='new installation; OS caches retained', unavailable=[*UNAVAILABLE, 'connector_cpu_ns']))
            with recorder.sample('startup') as sample:
                fixture.start()
                fixture.ready()
                sample.update(verified=True, definition=fixture.record()['definition'])
            journey = Journey(fixture, recorder)
            if args.scenario in ('console', 'all'):
                console(journey, args.repeat)
            if args.scenario in ('dataflow', 'all'):
                dataflow(journey, args.repeat)
            if args.scenario in ('webhook', 'all'):
                from interfaces.installation.webhook import run
                retained = run(journey, binaries)
            recorder.emit(dict(phase='resources', case='settled', processes=process_snapshot(fixture)))
            journey.close()
            journey = None
            with recorder.sample('retained_restart') as sample:
                fixture.stop()
                fixture.start()
                fixture.ready()
                journey = Journey(fixture, recorder)
                journey.rows('console_after_restart', 'SELECT * FROM items;', [])
                if retained is not None:
                    retained(journey)
                sample['verified'] = True
            success = True
        finally:
            try:
                if journey is not None:
                    journey.close()
                if fixture is not None:
                    fixture.cleanup()
            except BaseException:
                success = False
                raise
            finally:
                recorder.emit(dict(phase='campaign', outcome='complete' if success else 'failed'))
                if fixture is not None:
                    if success:
                        shutil.rmtree(fixture.root)
                    else:
                        print(f'Failed scenario installation retained at {fixture.root}', file=sys.stderr)
    from performance.load.scenario_report import summarize
    report = summarize([json.loads(line) for line in evidence.read_text().splitlines()])
    print(json.dumps(report), flush=True)


if __name__ == '__main__':
    main()
