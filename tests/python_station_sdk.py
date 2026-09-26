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
    from sdk_station_runner import Consumer, run as schedule
    def install(target):
        env = {k: v for k, v in os.environ.items() if k not in ('PYTHONPATH', 'PYTHONHOME', 'TRANSIT_LIBRARY_DIR')}
        venv = target / 'venv'
        subprocess.run([sys.executable, '-m', 'venv', '--without-pip', venv], check=True, env=env)
        python = venv / 'bin/python'
        subprocess.run([sys.executable, '-m', 'pip', '--python', python, 'install', '--no-index', '--find-links', str(Path(wheels).resolve()), 'transit-sdk-examples==0.2.0'], check=True, env=env, stdout=subprocess.DEVNULL)
        script = target / 'consumer.py'
        shutil.copyfile(__file__, script)
        return Consumer(env,
            lambda mode, config: [python, '-B', script, '--consumer', mode, config],
            lambda config, role: [venv / 'bin/transit-python-counter', config, role, '--commits', '1'],
            'coroutine-handler')
    schedule(node, cli, raw_library, install, 'Python')

if __name__ == '__main__':
    if sys.argv[1] == '--consumer': consumer(*sys.argv[2:])
    else: run(*sys.argv[1:])
