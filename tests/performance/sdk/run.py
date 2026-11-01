"""Verified installed SDK costs on one owned native-local service fixture."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import time

from harness.local_installation import freeze_executables
from harness.processes import joined
from harness.native_artifacts import describe
from interfaces.installation.server import Fixture
from performance.console import resources
from runner.capture import provenance, directory as evidence_directory
from runner.paths import ROOT
from sdk.consumer_registry import PERFORMANCE_CONSUMERS
from sdk.sdk_unified import Consumer

from performance.sdk.workload import LANGUAGES, cases, digest_rows, verify

RECORDING = None
DRIVERS = ('tests/performance/sdk/run.py', 'tests/performance/sdk/workload.py',
           'tests/performance/sdk/report.py', 'tests/interfaces/installation/server.py',
           'tests/harness/local_installation.py', 'tests/harness/processes.py',
           'tests/harness/native_artifacts.py', 'tests/runner/capture.py',
           'tests/performance/console/resources.py', 'tests/sdk/direct_sdk_catalog.py',
           'tests/sdk/sdk_unified.py', 'tests/sdk/consumer_registry.py',
           *dict.fromkeys(value[0] for value in PERFORMANCE_CONSUMERS.values()))


def emit(record):
    line = json.dumps(record)
    if RECORDING is not None:
        RECORDING.write(line + '\n')
        RECORDING.flush()
    print(line, flush=True)


def file_digest(path):
    with Path(path).open('rb') as file:
        return hashlib.file_digest(file, 'sha256').hexdigest()


def verify_native(target, language, native):
    if language == 'zig':
        return
    for family in ('client', 'station'):
        names = (f'libtransit_{family}.so', f'transit-{family}-host') if language.startswith('python-') else (f'transit-{family}-host',)
        for name in names:
            # pnpm also creates executable .bin launcher scripts with these
            # names. Verify the package's actual bin/lib artifacts, not shims.
            matches = [path for path in target.rglob(name) if path.parent.name in ('bin', 'lib')]
            if not matches:
                raise ValueError('missing installed native artifact')
            key = ('lib/' if name.endswith('.so') else 'bin/') + name
            expected = native['files'][key]['sha256']
            if any(file_digest(path) != expected for path in matches):
                raise ValueError('installed native artifact differs from declared build')


def measure(consumer, language, case, index, request, expected, *, warmup=False):
    row = dict(phase='operation', language=language, case=case, index=index,
               warmup=warmup, outcome='incomplete')
    started = time.perf_counter_ns()
    try:
        result = consumer.call(request)
        row['consumer'] = result
        verify(result, expected)
        row.update(outcome='complete', consumer=result)
        return result
    except BaseException as error:
        row.update(outcome='failed', error_type=type(error).__name__)
        raise
    finally:
        row['elapsed_ns'] = time.perf_counter_ns() - started
        emit(row)


def consume(language, command, env, target, fixture, args):
    started = time.perf_counter_ns()
    consumer = None
    cold = dict(phase='cold_start', language=language, outcome='incomplete')
    try:
        consumer = Consumer(command, env, target, read_timeout=180)
        cold['ready_ns'] = time.perf_counter_ns() - started
        first = consumer.call(dict(operation='lookup', name='sdk_items'))
        verify(first, dict(rows=args.rows, columns=2))
        cold.update(outcome='complete', first_verified_ns=time.perf_counter_ns() - started)
        emit(cold)
        emit(dict(phase='client', language=language, **consumer.call(dict(operation='info'))))
        next_id = (LANGUAGES.index(language) + 1) * 1_000_000
        def identify(request):
            nonlocal next_id
            next_id += 1
            return dict(request, id=str(next_id))
        for case, request, expected in cases(args.rows):
            for index in range(args.warmup + args.repeat):
                measure(consumer, language, case, index - args.warmup, identify(request), expected,
                        warmup=index < args.warmup)
        name = 'sdk_write_' + language.replace('-', '_')
        for count in (1, 8):
            for index in range(args.warmup + args.repeat):
                first_id = (count * 100000) + index * count
                values = [(first_id + i, 73 + first_id + i) for i in range(count)]
                sql = f'INSERT INTO {name} VALUES ' + ','.join(f'({a},{b})' for a, b in values)
                warmup = index < args.warmup
                measure(consumer, language, f'write_{count}', index - args.warmup,
                        identify(dict(operation='write', sql=sql)), dict(changed=count, matched=count), warmup=warmup)
                measure(consumer, language, f'read_after_write_{count}', index - args.warmup,
                        identify(dict(operation='query', name=name,
                            sql=f'SELECT id, value FROM {name} WHERE id >= {first_id} AND id < {first_id + count}')),
                        dict(rows=count, digest=digest_rows(values)), warmup=warmup)
        # Resource observations are separate from timed calls, include port-host
        # descendants, and refuse a changing process tree.
        processes = resources.tree([consumer.child.pid])
        observed = [resources.process(pid, 'sdk') for pid in sorted(processes)]
        if resources.tree([consumer.child.pid]) != processes:
            raise ValueError('SDK process tree changed during resource observation')
        emit(dict(phase='resources', language=language, processes=observed,
                  native_allocations=None, language_allocations=None, copies=None,
                  unavailable=['native_allocations', 'language_allocations', 'copies']))
    except BaseException as error:
        if cold['outcome'] != 'complete':
            cold.update(outcome='failed', elapsed_ns=time.perf_counter_ns() - started, error_type=type(error).__name__)
            emit(cold)
        raise
    finally:
        if consumer is not None:
            owned = resources.tree([consumer.child.pid])
            closing = time.perf_counter_ns()
            closed = dict(phase='close', language=language, outcome='incomplete')
            try:
                if consumer.child.poll() is not None:
                    raise ValueError('consumer exited before joined close')
                consumer.close()
                joined(owned)
                closed['outcome'] = 'complete'
            except BaseException as error:
                closed.update(outcome='failed', error_type=type(error).__name__)
                raise
            finally:
                consumer.close()
                closed['elapsed_ns'] = time.perf_counter_ns() - closing
                emit(closed)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('cli', 'node', 'host', 'zig', 'wheels', 'node-packages', 'native-prefix'):
        parser.add_argument('--' + name, required=True, type=Path)
    parser.add_argument('--native-record', type=Path, help='source record printed by native_artifacts.py prepare')
    parser.add_argument('--repeat', type=int, default=5, choices=range(1, 1001))
    parser.add_argument('--warmup', type=int, default=1, choices=range(11))
    parser.add_argument('--rows', type=int, default=70, choices=range(16, 1001))
    parser.add_argument('--maintenance', choices=('enabled', 'disabled'), default='enabled')
    parser.add_argument('--language', action='append', choices=LANGUAGES)
    args = parser.parse_args()
    languages = args.language or list(LANGUAGES)
    if len(set(languages)) != len(languages):
        parser.error('each language can be selected only once')
    global RECORDING
    evidence = evidence_directory(ROOT / '.cache/performance/sdk/campaign.json') / 'observations.jsonl'
    RECORDING = evidence.open('x')
    print(f'SDK benchmark observations: {evidence}', file=sys.stderr)
    fixture, success = None, False
    try:
        emit(dict(phase='campaign', outcome='started', languages=languages, repeat=args.repeat, warmup=args.warmup))
        fixture = Fixture(args.cli, args.node, args.host)
        native = describe(args.native_prefix)
        native_provenance = None
        if args.native_record is not None:
            recorded = json.loads(args.native_record.read_text())
            if any(recorded.get(key) != value for key, value in native.items()):
                raise ValueError('native source record does not describe these artifacts')
            native_provenance = {key: recorded[key] for key in ('revision', 'dirty', 'source_sha256')}
        if native['build']['optimize'] != 'safe' or native['build']['set'] != 'clients':
            raise ValueError('SDK benchmark requires the declared ReleaseSafe client build')
        freeze_executables(fixture)
        if args.maintenance == 'disabled':
            fixture.config['storage'] = dict(maintenance=dict(
                flush=dict(enabled=False), archive=dict(enabled=False), compact=False))
        fixture.path.write_text(json.dumps(fixture.config))
        fixture.start()
        fixture.ready()
        fixture.console('CREATE TABLE sdk_items (id BIGINT PRIMARY KEY, value BIGINT);')
        for start in range(0, args.rows, 20):
            values = ','.join(f'({i},{73+i})' for i in range(start, min(start+20, args.rows)))
            result, = fixture.console('INSERT INTO sdk_items VALUES ' + values + ';')
            assert int(result['completion']['counts']['changed']) == min(20, args.rows-start)
        for language in languages:
            fixture.console(f'CREATE TABLE sdk_write_{language.replace("-", "_")} (id BIGINT PRIMARY KEY, value BIGINT);')
        config = dict(url=fixture.url, service_url=f"http://127.0.0.1:{fixture.config['ports']['node']}",
                      seed_file=str(fixture.installation / 'caller.seed'),
                      connection=fixture.record()['default_table']['connection'])
        if native['definition'] != fixture.record()['definition']:
            raise ValueError('SDK and service definitions differ')
        emit(dict(phase='manifest', version=1, source=provenance(ROOT), definition=fixture.record()['definition'],
            cli_version=subprocess.check_output([fixture.cli, '--version'], text=True).strip(),
            native_build=native, native_provenance=native_provenance,
            drivers={path: file_digest(ROOT / path) for path in DRIVERS},
            binaries={role: file_digest(path) for role, path in dict(cli=fixture.cli, **fixture.config['executables']).items()},
            system=platform.platform(), machine=platform.machine(), cpus=os.cpu_count(), load=os.getloadavg(),
            host_id=file_digest('/proc/sys/kernel/random/boot_id'), storage_device=fixture.root.stat().st_dev,
            toolchain={name: subprocess.check_output(command, text=True).strip() for name, command in
                       dict(zig=['zig', 'version'], python=[sys.executable, '--version'], node=['node', '--version']).items()},
            maintenance=args.maintenance, build_mode='ReleaseSafe', storage_block_size=os.statvfs(fixture.root).f_bsize,
            languages=languages, rows=args.rows, repeat=args.repeat, warmup=args.warmup,
            durability='native-local synchronous; caller request/reference file+directory sync',
            cache='new consumer per language; OS/server caches retained; no eviction',
            completion='Catalog original committed outcome; Query exact retained snapshot through terminal coverage and release',
            unsupported=['relational ORDER BY', 'ordinary SQL/context language adapters', 'transactions', 'concurrent facets',
                         'nested/wide values', 'cancel/revocation/reply-loss schedules'],
            fault_qualification='existing installed Catalog/Query schedules; not executed by this timing driver'))
        for language in languages:
            target = fixture.root / language
            prepared = time.perf_counter_ns()
            source, install = PERFORMANCE_CONSUMERS[language]
            if language.startswith('python-'):
                python, env, artifacts = install(args.wheels, target)
                script = target / 'consumer.py'
                shutil.copy2(ROOT / source, script)
                command = [python, '-B', str(script), language.removeprefix('python-'), str(target / 'client.json')]
            elif language == 'node':
                env, artifacts = install(args.node_packages, target)
                script = target / 'consumer.mjs'
                shutil.copy2(ROOT / source, script)
                command = ['node', str(script), str(target / 'client.json')]
            else:
                target.mkdir()
                binary = target / 'consumer'
                shutil.copy2(args.zig, binary)
                artifacts = dict(zig=file_digest(binary))
                env = {key: value for key, value in os.environ.items() if key not in ('PYTHONPATH', 'TRANSIT_LIBRARY_DIR')}
                command = [str(binary), str(target / 'client.json')]
            path = target / 'client.json'
            path.write_text(json.dumps(config))
            path.chmod(0o600)
            verify_native(target, language, native)
            emit(dict(phase='package_preparation', language=language,
                      elapsed_ns=time.perf_counter_ns()-prepared, artifacts=artifacts))
            consume(language, command, env, target, fixture, args)
        success = True
    finally:
        try:
            if fixture is not None:
                try:
                    fixture.cleanup()
                    if success:
                        shutil.rmtree(fixture.root)
                except BaseException:
                    success = False
                    raise
                finally:
                    if not success:
                        print(f'SDK benchmark fixture retained at {fixture.root}', file=sys.stderr)
        finally:
            try:
                emit(dict(phase='campaign', outcome='complete' if success else 'failed'))
            finally:
                RECORDING.close()
                RECORDING = None


if __name__ == '__main__':
    main()
