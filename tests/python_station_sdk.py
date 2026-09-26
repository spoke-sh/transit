"""Clean installed public Station SDK: real authority, callbacks and host loss."""
import asyncio
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
import pickle
import select
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import threading
import time


def consumer(mode, config_path):
    import transit_station as station
    from transit_client import Client, ClientConfig, ProcessRef
    from transit_client.errors import Busy, CodecError, TurnExpired, ReadFailed, StaleOwnership, AccessDenied, ProcessRetired, HandlerError
    from transit_station import Runner, AsyncRunner, Recovery, FailurePolicy, Committed, NeedsRecovery, Blocked, Idle
    from transit_sdk_examples import codecs
    from transit_sdk_examples.counter import Counter, Requester, configuration, TOTAL
    from transit_sdk_examples.query import TableService, QueryRequester
    cfg = json.loads(Path(config_path).read_bytes())
    assert Path(station.__file__).is_relative_to(Path(sys.prefix))
    config, peer = configuration(Path(config_path))
    if mode == 'arrow':
        # Core clean-wheel checks already ran without Arrow. Supply the pinned
        # optional consumer from Nix for this adapter qualification only.
        sys.path.append(cfg['arrow_site'])
        segments = [pickle.loads(Path(cfg['output'], f'{i}.segment').read_bytes()) for i in range(6)]
        assert sum(segment.to_pyarrow().num_rows for segment in segments) == 41
        return
    if mode == 'codecs':
        fixtures = json.loads(Path(cfg['fixtures']).read_bytes())
        for case in fixtures['valid']:
            codec = getattr(codecs, case['codec'])
            data = bytes.fromhex(case['hex'])
            value = codec.decode(data)
            assert codec.encode(value) == data
            if case['codec'] == 'u64': assert value == int(case['value'])
            else:
                assert type(value).__name__ == case['variant']
                for name in ('key', 'value'):
                    if name in case: assert getattr(value, name) == (None if case[name] is None else int(case[name]))
        for case in fixtures['invalid']:
            try: getattr(codecs, case['codec']).decode(bytes.fromhex(case['hex']))
            except ValueError: pass
            else: raise AssertionError(case)
        for invalid in (True, -1, 2**64):
            try: codecs.u64.encode(invalid)
            except ValueError: pass
            else: raise AssertionError('Invalid full-width integer accepted')
        from transit_station import encode_cast
        assert encode_cast(codecs.Add(2**53+1), codecs.counter_codec) == b'STN1\x01' + bytes(8) + codecs.counter.encode(codecs.Add(2**53+1))
        print('codecs passed')
        return
    class CounterProof(Counter):
        initialized = handled = 0
        escaped = None
        def initialize(self, turn):
            self.initialized += 1
            assert turn.budgets.mutations == 3
            super().initialize(turn)
        def handle(self, turn, incoming):
            self.handled += 1
            self.escaped = turn
            caught = []
            def foreign():
                try: turn.state.require(TOTAL)
                except Busy: caught.append(True)
            thread = threading.Thread(target=foreign)
            thread.start()
            thread.join()
            assert caught == [True]
            super().handle(turn, incoming)
    handler, codec = CounterProof(), codecs.counter_codec
    if cfg['role'] == 'requester': handler, codec = Requester(peer), codecs.requester_codec
    elif cfg['role'] == 'table':
        from transit_station import Cast, Row, ReadVersion
        from transit_sdk_examples.query import TABLE
        class TableProof(TableService):
            def handle(self, turn, incoming):
                saved = Path(cfg['output']) / 'version.json'
                if isinstance(incoming, Cast) and isinstance(incoming.value, codecs.Rows):
                    cursor, rows, pages = None, [], 0
                    while True:
                        page = turn.table(TABLE).page(cursor)
                        assert len(page.entries) <= 8 and page.basis == turn.table(TABLE).basis
                        rows.extend(page.entries)
                        pages += 1
                        cursor = page.next
                        if cursor is None: break
                    assert len(rows) == 41 and pages == 6
                    assert rows[0].key == -(2**63) and rows[0].value is None
                    version = turn.retain()
                    saved.write_text(json.dumps({'pid': version.pid, 'input': version.input, 'index': version.index}))
                    turn.table(TABLE).update(Row(-(2**63), 17))
                elif isinstance(incoming.value, codecs.Initialize) and saved.exists():
                    version = ReadVersion(**json.loads(saved.read_bytes()))
                    assert turn.table(TABLE).get(-(2**63)).value == 17
                    source = turn.open_version(version)
                    assert source.table(TABLE).get(-(2**63)).value is None
                    assert len(source.table(TABLE).page().entries) == 8
                    assert len(source.state.page().entries) <= 8
                    turn.release(version)
                else:
                    super().handle(turn, incoming)
        handler, codec = TableProof(peer), codecs.query_service_codec
    elif cfg['role'] == 'query':
        def consume(segment):
            # These bytes remain valid after reader/runner disposal.
            output = Path(cfg['output'])
            (output / f'{segment.ordinal}.arrow').write_bytes(segment.ipc)
            (output / f'{segment.ordinal}.segment').write_bytes(pickle.dumps(segment))
            (output / 'manifest.json').write_text(json.dumps({'rows': segment.manifest.rows,
                'segments': segment.manifest.segments, 'correlation': segment.manifest.correlation, 'source': segment.manifest.source.pid,
                'destination': segment.manifest.destination.pid, 'resource': segment.manifest.basis.resource.resource,
                'revision': segment.manifest.basis.revision, 'bytes': segment.manifest.byte_count}))
        class QueryProof(QueryRequester):
            def handle(self, turn, incoming):
                if Path(cfg['output'], 'manifest.json').exists():
                    manifest = json.loads(Path(cfg['output'], 'manifest.json').read_bytes())
                    reader = turn.result(manifest['correlation'])
                    assert reader.manifest.rows == 41
                    Path(cfg['output'], 'ready').touch()
                    deadline = time.monotonic() + 30
                    while not Path(cfg['output'], 'continue').exists():
                        if time.monotonic() > deadline: raise TimeoutError('Revocation barrier')
                        time.sleep(0.01)
                    reader.segment(0)
                else:
                    super().handle(turn, incoming)
        handler, codec = QueryProof(peer, consume), codecs.query_requester_codec
    if mode.startswith('handler-'):
        def broken(turn, incoming):
            turn.state.put(TOTAL, 73)
            raise HandlerError('injected handler failure')
        handler.handle = broken
    elif mode == 'coroutine-handler':
        async def wrong(turn): pass
        handler.initialize = wrong
    class Store:
        current = None
        before_failed, confirm_failed = set(), set()
        saved, confirmations = {}, {}
        def before_dispatch(self, mutation):
            self.current = mutation
            if mode == 'gates':
                for callback in (self.runner.next, self.runner.close):
                    try: callback()
                    except Busy: pass
                    else: raise AssertionError('Recovery hook reentered its runner')
            if mode == 'gates' and mutation.purpose not in self.before_failed:
                self.before_failed.add(mutation.purpose)
                raise OSError('injected persistence failure')
            previous = self.saved.setdefault(mutation.identity, mutation.export())
            assert previous == mutation.export()
            path = Path(cfg['pending'])
            path.write_bytes(mutation.export())
            path.chmod(0o600)
        def confirmed(self, identity, receipt):
            assert identity in self.saved and receipt.position > 0
            if mode == 'gates' and self.current.purpose not in self.confirm_failed:
                self.confirm_failed.add(self.current.purpose)
                raise OSError('injected confirmation failure')
            self.confirmations[identity] = receipt
    store = Store()
    policy = FailurePolicy.BLOCK_INPUT if mode in ('decode-block', 'handler-block') else FailurePolicy.STOP
    recovery = Recovery.persist_before_dispatch(store)
    if mode == 'recover':
        with Client.open(ClientConfig(config.url, config.profile)) as client:
            with client.recover_mutation(Path(cfg['pending']).read_bytes()) as pending:
                assert pending.info.command in ('turn', 'turn_with_versions')
                receipt = client.dispatch_mutation(pending)
                assert receipt == client.last_mutation_receipt
                print(json.dumps({'receipt': receipt.position}))
        return
    if mode == 'async':
        async def run():
            runner = await AsyncRunner.open(config, handler=handler, codec=codec, failure_policy=policy, recovery=recovery)
            assert not isinstance(await runner.next(), Committed)  # Open the view first.
            task = asyncio.create_task(runner.next())
            deadline = time.monotonic() + 20
            while not Path(cfg['output'], 'accepted').exists():
                assert not task.done() and time.monotonic() < deadline, 'Commit did not reach the proxy'
                await asyncio.sleep(0.01)
            try: await runner.next()
            except Busy: pass
            else: raise AssertionError('Overlapping runner operation accepted')
            task.cancel()
            try: await task
            except asyncio.CancelledError: pass
            close = asyncio.create_task(runner.aclose())
            beats = 0
            while not close.done():
                beats += 1
                await asyncio.sleep(0.01)
            await close
            assert beats > 5 and isinstance(runner.last_event, Committed)
            assert handler.handled == 1 and runner.pending is None
            print(json.dumps({'cancelled': True, 'committed': True, 'beats': beats}))
        asyncio.run(run())
        return
    if mode == 'denied':
        try: Runner.open(config, handler=handler, codec=codec, failure_policy=policy, recovery=recovery)
        except AccessDenied: return
        raise AssertionError('Revoked identity opened a runner')
    with Runner.open(config, handler=handler, codec=codec, failure_policy=policy, recovery=recovery) as runner:
        store.runner = runner
        if mode == 'gates':
            original = runner._native.api.call
            allocated, dispatched = set(), []
            def fault(name, *args, **kwargs):
                result = original(name, *args, **kwargs)
                if name == 'station_growing_dispatch':
                    purpose = store.current.purpose
                    dispatched.append(purpose)
                    if purpose not in allocated:
                        allocated.add(purpose)
                        raise MemoryError('injected host response allocation failure')
                return result
            runner._native.api.call = fault
            phases = set()
            for _ in range(40):
                event = runner.next()
                if isinstance(event, NeedsRecovery):
                    phases.add(event.phase)
                    if event.phase == 'confirm': assert event.receipt is not None
                    assert runner.next() is event
                    event = runner.reconcile()
                if isinstance(event, Committed): break
            else: raise AssertionError('Recovery did not finish')
            assert phases == {'persist', 'dispatch', 'confirm'}
            assert set(dispatched) == {'permit', 'open', 'commit'} and len(dispatched) == 3
            assert len(store.confirmations) == 3 and handler.initialized == handler.handled == 1
            try: handler.escaped.state.require(TOTAL)
            except TurnExpired: pass
            else: raise AssertionError('Escaped turn remained usable')
            print(json.dumps({'gates': sorted(dispatched), 'handled': handler.handled, 'dispatches': len(dispatched)}))
            return
        if mode.startswith(('decode-', 'handler-')) or mode == 'coroutine-handler':
            for _ in range(8):
                try: event = runner.next()
                except (CodecError, HandlerError) as error:
                    assert mode in ('decode-stop', 'handler-stop', 'coroutine-handler')
                    assert isinstance(error, CodecError if mode == 'decode-stop' else HandlerError)
                    break
                if isinstance(event, Blocked):
                    assert mode in ('decode-block', 'handler-block') and event.receipt is not None
                    break
            else: raise AssertionError('Malformed codec did not stop')
            assert handler.handled == 0
            assert handler.initialized == (1 if mode.startswith('handler-') else 0)
            return
        if mode in ('stale', 'denied', 'expired', 'revoked-result'):
            try:
                for _ in range(8): runner.next()
            except (StaleOwnership, AccessDenied, ProcessRetired, HandlerError) as error:
                assert isinstance(error, StaleOwnership if mode == 'stale' else ProcessRetired if mode == 'expired' else AccessDenied)
                print(json.dumps({'denied': True}), flush=True)
            else: raise AssertionError('Invalid ownership/access accepted')
            return
        if mode == 'poison':
            # Even a handler which catches its read failure cannot commit.
            def poisoned(turn, incoming):
                try: turn.state.require(TOTAL)
                except ReadFailed: pass
            handler.handle = poisoned
            try:
                for _ in range(8): runner.next()
            except ReadFailed: pass
            else: raise AssertionError('Caught native read failure committed')
            return
        for line in sys.stdin:
            action = line.strip()
            if action == 'close':
                print(json.dumps({'closed': True}), flush=True)
                return
            if action != 'one': raise AssertionError(action)
            for _ in range(32):
                event = runner.next()
                if isinstance(event, (Committed, NeedsRecovery, Blocked, Idle)): break
            if isinstance(event, NeedsRecovery):
                assert event.mutation.export() == Path(cfg['pending']).read_bytes()
                response = {'event': 'NeedsRecovery', 'phase': event.phase, 'code': event.error.code}
            else:
                response = {'event': type(event).__name__}
            print(json.dumps(response), flush=True)


def run(node, cli, raw_library, wheels):
    from client_abi_growing import GrowingSystem
    from client_abi import Native
    from station import frame
    from sdk_scenarios import check
    root = Path(__file__).resolve().parents[1]
    fixture = GrowingSystem(node, cli)
    fixture.resident_pages = 64
    with tempfile.TemporaryDirectory(prefix='transit-station-consumer-') as temporary, fixture as system:
        target = Path(temporary)
        env = {k: v for k, v in os.environ.items() if k not in ('PYTHONPATH', 'PYTHONHOME', 'TRANSIT_LIBRARY_DIR')}
        venv = target / 'venv'
        subprocess.run([sys.executable, '-m', 'venv', '--without-pip', venv], check=True, env=env)
        python = venv / 'bin/python'
        subprocess.run([sys.executable, '-m', 'pip', '--python', python, 'install', '--no-index', '--find-links', str(Path(wheels).resolve()), 'transit-sdk-examples==0.2.0'], check=True, env=env, stdout=subprocess.DEVNULL)
        script = target / 'consumer.py'
        shutil.copyfile(__file__, script)
        codec_fixture = target / 'codecs.json'
        shutil.copyfile(root / 'tests/verification/sdk-codecs-v1.json', codec_fixture)
        native = Native(raw_library)
        admin = native.client(system.url)
        private = bytes.fromhex(system.seed.read_text().strip())
        sequence, principal = 0, 65536
        def command(body):
            nonlocal sequence
            sequence += 1
            op = native.prepare(6, private, {'realm': 72, 'principal': 0, 'sequence': sequence, 'command': body})
            try: return native.call(admin, op)['position']
            finally: native.lib.transit_operation_destroy(op)
        def read(kind):
            op = native.prepare(7, private, {'realm': 72, 'principal': 0, 'kind': kind})
            try: return native.call(admin, op)
            finally: native.lib.transit_operation_destroy(op)
        fault = {'drop': False, 'delay': False, 'poison': False, 'commands': [], 'poisoned': False}
        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_): pass
            def do_POST(self):
                body = self.rfile.read(int(self.headers['Content-Length']))
                conn = HTTPConnection('127.0.0.1', system.port, timeout=30)
                try:
                    conn.request('POST', self.path, body, {'Content-Type': 'application/json'})
                    result = conn.getresponse()
                    data = result.read()
                    if self.path == '/v3/command':
                        fault['commands'].append(body)
                        mutation = json.loads(body)['request']['command']
                        if ('turn' in mutation or 'turn_with_versions' in mutation) and result.status == 200:
                            if fault['delay']:
                                fault['delay_marker'].touch()
                                time.sleep(0.7)
                            if fault['drop']:
                                fault['drop'] = False
                                self.close_connection = True
                                return
                    elif fault['poison'] and not fault['poisoned'] and self.path == '/v3/query':
                        query = json.loads(body)['query']['kind']
                        if 'entries' in query and query['entries'].get('key') == b'total'.hex():
                            parsed = json.loads(data)
                            parsed['realm'] += 1
                            data = json.dumps(parsed).encode()
                            fault['poisoned'] = True
                    self.send_response(result.status)
                    self.send_header('Content-Length', str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                finally: conn.close()
        proxy = ThreadingHTTPServer(('127.0.0.1', 0), Proxy)
        thread = threading.Thread(target=proxy.serve_forever, daemon=True)
        thread.start()
        url = f'http://127.0.0.1:{proxy.server_port}'
        children = []
        def provision(role='service', finite=False, lifetime_ms=240000):
            nonlocal principal
            principal += 1
            now = time.time_ns() // 1_000_000
            pid = command({'spawn': {'work_before_ms': now+lifetime_ms, 'settle_before_ms': now+lifetime_ms+30000} if finite else {}})
            seed, public = system.key(f'public-{principal}')
            command({'grant': {'subject': principal, 'public_key': public, 'permissions': 88, 'pid': pid}})
            resource = command({'create_resource': {'writer': pid}})
            for subject in (0, principal): command({'grant_resource': {'resource': resource, 'subject': subject, 'permissions': 7}})
            command({'associate': {'pid': pid, 'name': b'data'.hex(), 'resource': resource}})
            command({'own': {'pid': pid, 'worker': principal, 'expected_generation': 1}})
            output = target / f'output-{pid}'
            output.mkdir()
            cfg = {'url': url, 'realm': 72, 'principal': principal, 'pid': pid, 'generation': 2,
                'seed_file': str(seed), 'profile': 'growing_v3', 'peer': pid, 'role': role, 'resource': resource,
                'pending': str(target / f'pending-{pid}'), 'output': str(output), 'fixtures': str(codec_fixture),
                'query_results': role in ('table', 'query'), 'work_before_ms': now+lifetime_ms if finite else None}
            return cfg
        def config_file(cfg):
            path = target / f"config-{cfg['pid']}.json"
            path.write_text(json.dumps(cfg))
            return path
        def invoke(mode, cfg):
            return subprocess.check_output([python, '-B', script, '--consumer', mode, config_file(cfg)], env=env, cwd=target, timeout=90, text=True)
        def worker(cfg):
            child = subprocess.Popen([python, '-B', script, '--consumer', 'worker', config_file(cfg)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, env=env, cwd=target, text=True)
            children.append(child)
            return child
        def one(child):
            child.stdin.write('one\n'); child.stdin.flush()
            assert select.select([child.stdout], [], [], 180)[0], 'Public runner timed out'
            value = child.stdout.readline()
            assert value, f'Worker failed with {child.poll()}'
            return json.loads(value)
        def close(child):
            child.stdin.write('close\n'); child.stdin.flush()
            assert json.loads(child.stdout.readline()) == {'closed': True}
            child.stdin.close()
            assert child.wait(timeout=15) == 0
            child.stdout.close()
            children.remove(child)
        def send(cfg, payload): command({'send': {'pid': cfg['pid'], 'value': frame(payload)}})
        def own(cfg):
            command({'own': {'pid': cfg['pid'], 'worker': cfg['principal'], 'expected_generation': cfg['generation']}})
            cfg['generation'] += 1
        after = None
        def deliver():
            nonlocal after
            position = read({'capabilities': {}})['position']
            batch = read({'outputs': {'after': after, 'position': position}})['body']['outputs']
            for value in batch['entries']:
                if value:
                    if value['phase'] == 'pending': command({'deliver': value['id']})
                    after = value['id']
        def process(cfg): return read({'process': cfg['pid']})['body']['process']['process']
        try:
            gated = provision(finite=True)
            invoke('codecs', gated)
            send(gated, b'TSC\x01\x01' + (2**53+1).to_bytes(8, 'little'))
            gates = json.loads(invoke('gates', gated))
            assert gates['gates'] == ['commit', 'open', 'permit']
            assert process(gated)['consumed'] == 1
            for mode in ('decode-stop', 'decode-block', 'handler-stop', 'handler-block', 'coroutine-handler'):
                cfg = provision()
                send(cfg, b'TSC\x02\x02' if mode.startswith('decode-') else b'TSC\x01\x01' + (1).to_bytes(8, 'little'))
                invoke(mode, cfg)
                state = process(cfg)
                assert state['consumed'] == 0 and (state['failure'] is not None) == (mode in ('decode-block', 'handler-block'))
                assert read({'resource': cfg['resource']})['body']['resource']['entries'] == 0
            async_cfg = provision()
            send(async_cfg, b'TSC\x01\x01' + (5).to_bytes(8, 'little'))
            fault['delay_marker'] = Path(async_cfg['output'], 'accepted')
            fault['delay'] = True
            assert json.loads(invoke('async', async_cfg))['committed']
            fault['delay'] = False
            assert process(async_cfg)['consumed'] == 1
            # Unknown accepted commit survives abrupt host loss and exact raw recovery.
            source, requester = provision(), provision('requester')
            requester['peer'] = source['pid']
            send(source, b'TSC\x01\x01' + (2**64-1).to_bytes(8, 'little'))
            service = worker(source)
            fault['drop'] = True
            assert one(service)['event'] == 'NeedsRecovery'
            accepted = fault['commands'][-1]
            service.kill(); service.wait(timeout=10); children.remove(service)
            system.authority.kill(); system.authority.wait(timeout=10)
            system.store.stop(); system.store.start()
            system.authority = system.start(node, system.config)
            from storage import wait_ready
            wait_ready(system.store.http, system.authority, system.url + '/health')
            seed_path = Path(source['seed_file'])
            saved_seed = seed_path.read_bytes(); seed_path.unlink()
            invoke('recover', source)
            exact_commit_retry = fault['commands'][-1] == accepted
            assert exact_commit_retry and process(source)['consumed'] == 1
            seed_path.write_bytes(saved_seed)
            own(source)
            send(requester, b'TSC\x01\x03')
            caller = worker(requester)
            assert one(caller)['event'] == 'Committed'
            close(caller)
            own(requester)
            deliver()
            # Run the installed documented CLI, rather than a test-only handler.
            subprocess.run([venv / 'bin/transit-python-counter', config_file(source), 'service', '--commits', '1'], env=env, cwd=target, check=True, timeout=60, stdout=subprocess.DEVNULL)
            deliver()
            subprocess.run([venv / 'bin/transit-python-counter', config_file(requester), 'requester', '--commits', '1'], env=env, cwd=target, check=True, timeout=60, stdout=subprocess.DEVNULL)
            assert process(requester)['consumed'] == 2
            revision = read({'resource': requester['resource']})['body']['resource']['revision']
            entries = read({'entries': {'resource': requester['resource'], 'revision': revision, 'key': b'observed'.hex()}})['body']['entries']['page']['entries']
            observed = next(entry for entry in entries if entry)
            assert bytes.fromhex(observed['value']) == b'TSU\x01' + (2**64-1).to_bytes(8, 'little')
            old = dict(source)
            own(source)
            invoke('stale', old)
            # A caught failed read must still abort the whole private turn.
            send(source, b'TSC\x01\x01' + (0).to_bytes(8, 'little'))
            fault['poison'] = True
            invoke('poison', source)
            assert fault['poisoned'] and process(source)['consumed'] == 2
            fault['poison'] = False
            command({'revoke': source['principal']})
            invoke('denied', source)
            # Bounded Table pages, retained point reads and multi-segment IPC.
            expired = provision(finite=True, lifetime_ms=2000)
            table, query_cfg = provision('table'), provision('query')
            table['peer'], query_cfg['peer'] = query_cfg['pid'], table['pid']
            service, caller = worker(table), worker(query_cfg)
            send(table, b'TSQ\x01\x01')
            assert one(service)['event'] == 'Committed'
            for index in range(41):
                key = -(2**63) if index == 0 else index
                value = None if index % 5 == 0 else 2**63-1 if index == 1 else 2**53+1
                payload = b'TSQ\x01\x02' + key.to_bytes(8, 'little', signed=True)
                payload += b'\0' if value is None else b'\1' + value.to_bytes(8, 'little', signed=True)
                send(table, payload)
                assert one(service)['event'] == 'Committed'
            send(table, b'TSQ\x01\x03')
            assert one(service)['event'] == 'Committed'
            send(table, b'TSQ\x01\x01')
            assert one(service)['event'] == 'Committed'
            send(query_cfg, b'TSQ\x01\x04')
            assert one(caller)['event'] == 'Committed'
            close(caller)
            own(query_cfg)
            caller = worker(query_cfg)
            manifest_file = Path(query_cfg['output']) / 'manifest.json'
            for _ in range(150):
                deliver()
                assert one(service)['event'] in ('Committed', 'Idle')
                assert one(caller)['event'] in ('Committed', 'Idle')
                if manifest_file.exists(): break
            else: raise AssertionError('Public query did not complete')
            close(service); close(caller)
            manifest = json.loads(manifest_file.read_bytes())
            assert (manifest['rows'], manifest['segments'], manifest['source'], manifest['destination'], manifest['resource']) == (41, 6, table['pid'], query_cfg['pid'], table['resource'])
            # Independent consumer after all foreign handles have been destroyed.
            import pyarrow as pa
            segments = [Path(query_cfg['output'], f'{i}.arrow').read_bytes() for i in range(6)]
            rows = [row for ipc in segments for row in pa.ipc.open_stream(ipc).read_all().to_pylist()]
            assert len(rows) == 41 and rows[0] == {'id': -(2**63), 'value': 17}
            assert rows[1]['value'] == 2**63-1 and rows[2]['value'] == 2**53+1
            assert sum(map(len, segments)) == manifest['bytes']
            own(query_cfg)
            send(query_cfg, b'TSQ\x01\x04')
            reader_child = subprocess.Popen([python, '-B', script, '--consumer', 'revoked-result', config_file(query_cfg)], stdout=subprocess.PIPE, env=env, cwd=target, text=True)
            children.append(reader_child)
            deadline = time.monotonic() + 45
            while not Path(query_cfg['output'], 'ready').exists():
                assert reader_child.poll() is None and time.monotonic() < deadline, 'Reader was not ready'
                time.sleep(0.02)
            command({'grant_resource': {'resource': query_cfg['resource'], 'subject': query_cfg['principal'], 'permissions': 0}})
            Path(query_cfg['output'], 'continue').touch()
            denied = json.loads(reader_child.communicate(timeout=30)[0])
            assert denied == {'denied': True}
            assert reader_child.returncode == 0
            children.remove(reader_child)
            query_cfg['arrow_site'] = str(Path(pa.__file__).parent.parent)
            invoke('arrow', query_cfg)
            # Expiry remains retirement, distinct from stale activation or access.
            while time.time_ns() // 1_000_000 <= expired['work_before_ms'] + 10000:
                time.sleep(0.05)
            command({'expire': expired['pid']})
            invoke('expired', expired)
            check('public-runner-lifecycle', {
                'gated_purposes': gates['gates'], 'handler_calls_after_recovery': gates['handled'],
                'dispatches_after_host_allocation': gates['dispatches'], 'exact_commit_retry': exact_commit_retry,
                'restarted_reply_value': str(int.from_bytes(bytes.fromhex(observed['value'])[4:], 'little')),
                'query_rows': manifest['rows'], 'query_segments': manifest['segments'],
                'owned_ipc_after_close': not children, 'revoked_result_denied': denied['denied'],
            })
            print('Python Station: clean wheels/examples, full-width codecs, gated mutations, host allocation, persistence/confirmation failures, scope/thread safety, async cancellation/join, codec policy, poisoned reads, fencing/expiry, exact disk/host recovery, retained Tables and six owned IPC segments passed.')
        finally:
            for child in children:
                child.kill(); child.wait(timeout=10)
            native.lib.transit_client_destroy(admin)
            proxy.shutdown(); proxy.server_close(); thread.join(timeout=5)


if __name__ == '__main__':
    if sys.argv[1] == '--consumer': consumer(*sys.argv[2:])
    else: run(*sys.argv[1:])
