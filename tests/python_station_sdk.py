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
    if mode.startswith('document-'):
        document_consumer(mode, cfg)
        return
    if mode.startswith('grpc-'):
        grpc_consumer(mode, cfg)
        return
    if mode.startswith('http-'):
        return http_consumer(mode, cfg)
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
        from transit_client import ResourceRef
        from transit_client.errors import TransitError
        from transit_station import (HttpMethod, HttpRequest, Literal, Variable, SecretRef,
            HttpHeader, prepare_http, decode_http_reply, HttpOutcome, HttpPhase,
            HttpRejected, HttpReleased, HttpRejection, HttpReplyCodec)
        http_fixture = json.loads(Path(cfg['http_fixtures']).read_bytes())
        request = HttpRequest(HttpMethod.POST, (Literal('/write'),))
        prepared = prepare_http(ResourceRef(72, 8), 2**64-1, request,
            bytes.fromhex(http_fixture['body']), endpoint_revision=7,
            reconcile_before_ms=9000, max_attempts=2)
        assert prepared.reference.hex() == http_fixture['reference']
        assert prepared.metadata.decode() == http_fixture['metadata']
        outcome = decode_http_reply(72, bytes.fromhex(http_fixture['outcome']))
        assert isinstance(outcome, HttpOutcome) and outcome.phase is HttpPhase.OBSERVED
        assert outcome.exchange == 2**64-1 and outcome.status == 200 and outcome.reference
        assert decode_http_reply(72, bytes.fromhex(http_fixture['rejection'])) == HttpRejected(HttpRejection.DENIED)
        union = HttpReplyCodec(codecs.counter_codec, 72)
        assert union.decode(bytes.fromhex(http_fixture['outcome'])) == outcome
        disposal = json.loads(Path(cfg['http_release_fixtures']).read_bytes())
        released = HttpReleased(ResourceRef(72, 7), 2**64-1)
        assert union.decode(bytes.fromhex(disposal['reply'])) == released
        try: union.encode(released)
        except ValueError: pass
        else: raise AssertionError('Release acknowledgement is receive-only')
        try: decode_http_reply(72, bytes.fromhex(disposal['reply'])[:-1])
        except TransitError: pass
        else: raise AssertionError('Truncated release acknowledgement accepted')
        assert union.decode(union.encode(codecs.Add(2**53+1))) == codecs.Add(2**53+1)
        complex_request = HttpRequest(HttpMethod.POST, (Literal('/items/'), Variable('id', 'λ /')), (
            HttpHeader('X-Tag', (Literal('one'),)), HttpHeader('X-Tag', (Literal('two'),)),
            HttpHeader('Authorization', (Literal('Bearer '), SecretRef('api', 2**64-1)))))
        wide = prepare_http(ResourceRef(72, 8), 2**64-2, complex_request,
            endpoint_revision=2**64-1, reconcile_before_ms=9000)
        assert wide.body == b'' and b'18446744073709551615' in wide.metadata
        assert b'Bearer' not in repr(wide).encode() and b'Bearer' not in repr(complex_request).encode()
        for bad in (HttpRequest(HttpMethod.GET, (Literal('//other/'),)),
                    HttpRequest(HttpMethod.GET, (Literal('/'),), (HttpHeader('X-Test', (Literal('a\r\nb'),)),)),
                    HttpRequest(HttpMethod.GET, (Literal('/'), SecretRef('api', 1)))):
            try: prepare_http(ResourceRef(72, 8), 1, bad, endpoint_revision=1, reconcile_before_ms=9000)
            except TransitError: pass
            else: raise AssertionError('Invalid HTTP request accepted')
        for data in (b'', bytes.fromhex(http_fixture['outcome'])[:-1], b'HTR2' + bytes(67)):
            try: decode_http_reply(72, data)
            except TransitError: pass
            else: raise AssertionError('Invalid HTTP outcome accepted')
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
            if action == 'ready':
                print(json.dumps({'ready': True}), flush=True)
                continue
            if action == 'close':
                print(json.dumps({'closed': True}), flush=True)
                return
            if action not in ('one', 'reconcile'): raise AssertionError(action)
            for index in range(32):
                event = runner.reconcile() if action == 'reconcile' and index == 0 else runner.next()
                if isinstance(event, (Committed, NeedsRecovery, Blocked, Idle)): break
            if isinstance(event, NeedsRecovery):
                assert event.mutation.export() == Path(cfg['pending']).read_bytes()
                response = {'event': 'NeedsRecovery', 'phase': event.phase, 'code': event.error.code}
            else:
                response = {'event': type(event).__name__}
            print(json.dumps(response), flush=True)


def http_consumer(mode, cfg):
    from transit_client import ProcessRef, ResourceRef
    from transit_client.errors import AccessDenied, Busy, Closed, ReadFailed, TurnExpired
    from transit_station import (Activation, ServiceConfig, Runner, AsyncRunner,
        FailurePolicy, Recovery, Key, Cast, Reply, Committed, HttpReplyCodec,
        HttpRequest, HttpMethod, HttpHeader, Literal, Variable, SecretRef, prepare_http,
        HttpOutcome, HttpReleased, HttpPhase, HttpPartKind, decode_http_reply,
        HttpFollowupReason, HttpRejected, HttpRejection)
    from transit_sdk_examples.codecs import u64
    class Bytes:
        type_id, version, max_encoded_bytes = 'test.http-control', 1, 243
        def encode(self, value):
            assert isinstance(value, bytes)
            return value
        def decode(self, value): return value
    config = ServiceConfig(cfg['url'], 'native_v1', Activation(ProcessRef(72, cfg['pid']),
        cfg['principal'], cfg['generation'], Path(cfg['seed_file'])))
    peer = ProcessRef(72, cfg['peer'])
    request = prepare_http(ResourceRef(72, cfg['resource']), 2**64-1,
        HttpRequest(HttpMethod.POST, (Literal('/items/'), Variable('id', 'λ /')), (
            HttpHeader('X-Tag', (Literal('one'),)), HttpHeader('X-Tag', (Literal('two'),)),
            HttpHeader('Authorization', (Literal('Bearer '), SecretRef('api', 7))))),
        bytes.fromhex(cfg['body']), endpoint_revision=7, reconcile_before_ms=cfg['deadline'])
    correlation = Key(b'http-correlation', u64)
    status = Key(b'http-status', u64)
    disposal = Key(b'http-disposal', u64)
    followup = Key(b'http-followup', u64)
    codec = HttpReplyCodec(Bytes(), 72)
    class Handler:
        result = None
        escaped = None
        def initialize(self, turn): pass
        def handle(self, turn, incoming):
            self.escaped = turn
            if isinstance(incoming, Cast):
                if incoming.value == b'followup':
                    from dataclasses import replace
                    outcome = decode_http_reply(72, bytes.fromhex(cfg['outcome']))
                    assert isinstance(outcome, HttpOutcome)
                    reason = HttpFollowupReason(cfg['followup_reason'])
                    wrong = replace(outcome, resource=ResourceRef(73, outcome.resource.resource))
                    try: turn.followup_http(peer, wrong, reason, request)
                    except ValueError: pass
                    else: raise AssertionError('Cross-realm followup accepted')
                    call = turn.followup_http(peer, outcome, reason, request)
                    turn.state.put(followup, call)
                    self.result = {'followup': False}
                elif incoming.value == b'dispose':
                    outcome = decode_http_reply(72, bytes.fromhex(cfg['outcome']))
                    assert isinstance(outcome, HttpOutcome)
                    try: turn.release_http(peer, ResourceRef(73, outcome.resource.resource), outcome.exchange)
                    except ValueError: pass
                    else: raise AssertionError('Cross-realm disposal accepted')
                    call = turn.release_http(peer, outcome.resource, outcome.exchange)
                    turn.state.put(disposal, call)
                    self.result = {'released': False}
                elif turn.state.find(correlation) is not None:
                    self.result = {'called': True}
                elif turn.stage_http(request):
                    call = turn.call_http(peer, request)
                    turn.state.put(correlation, call)
                    self.result = {'called': True}
                else:
                    self.result = {'called': False}
            else:
                assert isinstance(incoming, Reply)
                if isinstance(incoming.value, HttpRejected):
                    turn.require_reply(incoming, peer=peer, correlation=turn.state.require(followup))
                    assert incoming.value.reason is HttpRejection.DENIED
                    turn.state.put(Key(b'http-followup-denied', u64), incoming.correlation)
                    self.result = {'followup': True}
                    return
                if isinstance(incoming.value, HttpReleased):
                    turn.require_reply(incoming, peer=peer, correlation=turn.state.require(disposal))
                    original = decode_http_reply(72, bytes.fromhex(cfg['outcome']))
                    assert (incoming.value.resource, incoming.value.exchange) == (original.resource, original.exchange)
                    turn.state.put(Key(b'http-disposed', u64), incoming.value.exchange)
                    self.result = {'released': True}
                    return
                assert isinstance(incoming.value, HttpOutcome)
                turn.require_reply(incoming, peer=peer, correlation=turn.state.require(correlation))
                assert incoming.value.phase is HttpPhase.OBSERVED and incoming.value.status == 200
                turn.state.put(status, incoming.value.status)
                self.result = {'observed': True}
    handler = Handler()
    options = dict(handler=handler, codec=codec, failure_policy=FailurePolicy.STOP,
                   recovery=Recovery.fence_on_restart())
    if mode == 'http-async':
        async def check():
            runner = await AsyncRunner.open(config, **options)
            outcome = decode_http_reply(72, bytes.fromhex(cfg['outcome']))
            reader = await runner.open_http(outcome)
            first = await reader.read()
            assert first.data and not first.complete
            Path(cfg['ready']).touch()
            while not Path(cfg['continue']).exists(): await asyncio.sleep(0.01)
            pending = asyncio.create_task(reader.read())
            deadline = time.monotonic() + 15
            while not Path(cfg['accepted']).exists():
                assert not pending.done() and time.monotonic() < deadline
                await asyncio.sleep(0.01)
            try: await reader.read()
            except Busy: pass
            else: raise AssertionError('Overlapping reader call accepted')
            pending.cancel()
            try: await pending
            except asyncio.CancelledError: pass
            close = asyncio.create_task(runner.aclose())
            beats = 0
            while not close.done():
                beats += 1
                await asyncio.sleep(0.01)
            await close
            assert beats > 5 and first.data
            try: await reader.read()
            except Closed: pass
            else: raise AssertionError('Disposed runner retained reader authority')
            print(json.dumps({'joined': True}), flush=True)
        asyncio.run(check())
        return
    with Runner.open(config, **options) as runner:
        reader, owned = None, bytearray()
        for line in sys.stdin:
            action = line.strip()
            if action == 'step':
                for _ in range(32):
                    if isinstance(runner.next(), Committed): break
                else: raise AssertionError('No committed caller turn')
                try: handler.escaped.stage_http(request)
                except TurnExpired: pass
                else: raise AssertionError('Escaped HTTP turn accepted')
                try: handler.escaped.release_http(peer, ResourceRef(72, cfg['resource']), 1)
                except TurnExpired: pass
                else: raise AssertionError('Escaped disposal turn accepted')
                if 'outcome' in cfg:
                    try: handler.escaped.followup_http(peer, decode_http_reply(72, bytes.fromhex(cfg['outcome'])), HttpFollowupReason.RETRY, request)
                    except TurnExpired: pass
                    else: raise AssertionError('Escaped followup turn accepted')
                result = handler.result
            elif action == 'open':
                outcome = decode_http_reply(72, bytes.fromhex(cfg['outcome']))
                reader = runner.open_http(outcome)
                try: runner.open_http(outcome)
                except Busy: pass
                else: raise AssertionError('Second active HTTP reader accepted')
                first = reader.read()
                assert first.data and not first.complete
                result = {'prefix': True}
            elif action == 'denied':
                try: reader.read()
                except AccessDenied: pass
                else: raise AssertionError('Revoked HTTP capture returned data')
                result = {'denied': True}
            elif action == 'reopen':
                try: reader.read()
                except ReadFailed as error: assert error.code == 'HttpReplayFailed'
                else: raise AssertionError('Failed HTTP reader resumed')
                reader.close()
                reader.close()
                with runner.open_http(outcome) as reader:
                    while (part := reader.read()) is not None:
                        if part.kind is HttpPartKind.RESPONSE_BODY: owned.extend(part.data)
                    assert reader.complete
                result = {'complete': True, 'body': owned.hex()}
            elif action == 'close':
                break
            else: raise AssertionError(action)
            print(json.dumps(result), flush=True)
    print(json.dumps({'closed': True, 'owned': owned.hex()}), flush=True)


def grpc_consumer(mode, cfg):
    from transit_client import ProcessRef, ResourceRef
    from transit_client.errors import AccessDenied, Busy, Closed, ReadFailed, TurnExpired
    from transit_station import (Activation, ServiceConfig, Runner, AsyncRunner,
        FailurePolicy, Recovery, Key, Cast, Reply, Committed, GrpcReplyCodec,
        GrpcRequest, GrpcMetadata, GrpcSecretRef, grpc_method, prepare_grpc,
        GrpcOutcome, GrpcReleased, GrpcPhase, GrpcPartKind, decode_grpc_reply,
        GrpcRejected, GrpcRejection)
    from transit_sdk_examples.codecs import u64
    class Bytes:
        type_id, version, max_encoded_bytes = 'test.grpc-control', 1, 243
        def encode(self, value):
            assert isinstance(value, bytes)
            return value
        def decode(self, value): return value
    config = ServiceConfig(cfg['url'], 'native_v1', Activation(ProcessRef(72, cfg['pid']),
        cfg['principal'], cfg['generation'], Path(cfg['seed_file'])))
    peer = ProcessRef(72, cfg['peer'])
    request = prepare_grpc(ResourceRef(72, cfg['resource']), 2**64-1,
        GrpcRequest(grpc_method(bytes.fromhex(cfg['descriptor']), cfg['method']), (
            GrpcMetadata('x-tag', b'one'), GrpcMetadata('x-tag', b'two'),
            GrpcMetadata('x-data-bin', b'\x00\xff'), GrpcMetadata('authorization', GrpcSecretRef('api', 7)))),
        (bytes.fromhex(cfg['body']), b''), endpoint_revision=7, reconcile_before_ms=cfg['deadline'])
    correlation = Key(b'grpc-correlation', u64)
    status = Key(b'grpc-status', u64)
    disposal = Key(b'grpc-disposal', u64)
    followup = Key(b'grpc-followup', u64)
    codec = GrpcReplyCodec(Bytes(), 72)
    class Handler:
        result = None
        escaped = None
        def initialize(self, turn): pass
        def handle(self, turn, incoming):
            self.escaped = turn
            if isinstance(incoming, Cast):
                if incoming.value == b'followup':
                    from dataclasses import replace
                    outcome = decode_grpc_reply(72, bytes.fromhex(cfg['outcome']))
                    assert isinstance(outcome, GrpcOutcome)
                    wrong = replace(outcome, resource=ResourceRef(73, outcome.resource.resource))
                    try: turn.retry_grpc(peer, wrong, request)
                    except ValueError: pass
                    else: raise AssertionError('Cross-realm followup accepted')
                    call = turn.retry_grpc(peer, outcome, request)
                    turn.state.put(followup, call)
                    self.result = {'followup': False}
                elif incoming.value == b'dispose':
                    outcome = decode_grpc_reply(72, bytes.fromhex(cfg['outcome']))
                    assert isinstance(outcome, GrpcOutcome)
                    try: turn.release_grpc(peer, ResourceRef(73, outcome.resource.resource), outcome.exchange)
                    except ValueError: pass
                    else: raise AssertionError('Cross-realm disposal accepted')
                    call = turn.release_grpc(peer, outcome.resource, outcome.exchange)
                    turn.state.put(disposal, call)
                    self.result = {'released': False}
                elif turn.state.find(correlation) is not None:
                    self.result = {'called': True}
                elif turn.stage_grpc(request):
                    call = turn.call_grpc(peer, request)
                    turn.state.put(correlation, call)
                    self.result = {'called': True}
                else:
                    self.result = {'called': False}
            else:
                assert isinstance(incoming, Reply)
                if isinstance(incoming.value, GrpcRejected):
                    turn.require_reply(incoming, peer=peer, correlation=turn.state.require(followup))
                    assert incoming.value.reason is GrpcRejection.DENIED
                    turn.state.put(Key(b'grpc-followup-denied', u64), incoming.correlation)
                    self.result = {'followup': True}
                    return
                if isinstance(incoming.value, GrpcReleased):
                    turn.require_reply(incoming, peer=peer, correlation=turn.state.require(disposal))
                    original = decode_grpc_reply(72, bytes.fromhex(cfg['outcome']))
                    assert (incoming.value.resource, incoming.value.exchange) == (original.resource, original.exchange)
                    turn.state.put(Key(b'grpc-disposed', u64), incoming.value.exchange)
                    self.result = {'released': True}
                    return
                assert isinstance(incoming.value, GrpcOutcome)
                turn.require_reply(incoming, peer=peer, correlation=turn.state.require(correlation))
                assert incoming.value.phase is GrpcPhase.OBSERVED and incoming.value.status == 0
                turn.state.put(status, incoming.value.status)
                self.result = {'observed': True}
    handler = Handler()
    options = dict(handler=handler, codec=codec, failure_policy=FailurePolicy.STOP,
                   recovery=Recovery.fence_on_restart())
    if mode == 'grpc-async':
        async def check():
            runner = await AsyncRunner.open(config, **options)
            outcome = decode_grpc_reply(72, bytes.fromhex(cfg['outcome']))
            reader = await runner.open_grpc(outcome)
            first = await reader.read()
            assert first.data and not first.complete
            Path(cfg['ready']).touch()
            while not Path(cfg['continue']).exists(): await asyncio.sleep(0.01)
            pending = asyncio.create_task(reader.read())
            deadline = time.monotonic() + 15
            while not Path(cfg['accepted']).exists():
                assert not pending.done() and time.monotonic() < deadline
                await asyncio.sleep(0.01)
            try: await reader.read()
            except Busy: pass
            else: raise AssertionError('Overlapping reader call accepted')
            pending.cancel()
            try: await pending
            except asyncio.CancelledError: pass
            close = asyncio.create_task(runner.aclose())
            beats = 0
            while not close.done():
                beats += 1
                await asyncio.sleep(0.01)
            await close
            assert beats > 5 and first.data
            try: await reader.read()
            except Closed: pass
            else: raise AssertionError('Disposed runner retained reader authority')
            print(json.dumps({'joined': True}), flush=True)
        asyncio.run(check())
        return
    with Runner.open(config, **options) as runner:
        reader, owned = None, bytearray()
        for line in sys.stdin:
            action = line.strip()
            if action == 'step':
                for _ in range(32):
                    if isinstance(runner.next(), Committed): break
                else: raise AssertionError('No committed caller turn')
                try: handler.escaped.stage_grpc(request)
                except TurnExpired: pass
                else: raise AssertionError('Escaped RPC turn accepted')
                try: handler.escaped.release_grpc(peer, ResourceRef(72, cfg['resource']), 1)
                except TurnExpired: pass
                else: raise AssertionError('Escaped disposal turn accepted')
                if 'outcome' in cfg:
                    try: handler.escaped.retry_grpc(peer, decode_grpc_reply(72, bytes.fromhex(cfg['outcome'])), request)
                    except TurnExpired: pass
                    else: raise AssertionError('Escaped followup turn accepted')
                result = handler.result
            elif action == 'open':
                outcome = decode_grpc_reply(72, bytes.fromhex(cfg['outcome']))
                reader = runner.open_grpc(outcome)
                try: runner.open_grpc(outcome)
                except Busy: pass
                else: raise AssertionError('Second active RPC reader accepted')
                first = reader.read()
                assert first.data and not first.complete
                result = {'prefix': True}
            elif action == 'denied':
                try: reader.read()
                except AccessDenied: pass
                else: raise AssertionError('Revoked RPC capture returned data')
                result = {'denied': True}
            elif action == 'reopen':
                try: reader.read()
                except ReadFailed as error: assert error.code == 'GrpcReplayFailed'
                else: raise AssertionError('Failed RPC reader resumed')
                reader.close()
                reader.close()
                with runner.open_grpc(outcome) as reader:
                    while (part := reader.read()) is not None:
                        if part.kind is GrpcPartKind.RESPONSE_BODY: owned.extend(part.data)
                    assert reader.complete
                result = {'complete': True, 'body': owned.hex()}
            elif action == 'close':
                break
            else: raise AssertionError(action)
            print(json.dumps(result), flush=True)
    print(json.dumps({'closed': True, 'owned': owned.hex()}), flush=True)


def document_consumer(mode, cfg):
    import transit_station as s
    from transit_client import ResourceRef, ProcessRef
    from transit_client.errors import AccessDenied, HandlerError, Closed, TransitError
    document = int(cfg['document'])
    resource = ResourceRef(cfg['realm'], cfg['resource'])
    if mode == 'document-codecs':
        fixtures = json.loads(Path(cfg['document_fixtures']).read_bytes())
        for case in fixtures['changes']:
            decoded = s.decode_document(bytes.fromhex(case['wire_hex']))
            assert s.prepare_document(decoded).data.hex() == case['wire_hex']
            for length in (0, 1, len(bytes.fromhex(case['wire_hex']))-1):
                try: s.decode_document(bytes.fromhex(case['wire_hex'])[:length])
                except TransitError: pass
                else: raise AssertionError('Truncated Document change accepted')
        ref = s.DocumentReference.decode(cfg['realm'], bytes.fromhex(fixtures['reference_hex']))
        assert ref.document == ref.revision == 2**64-1 and ref.encode().hex() == fixtures['reference_hex']
        bootstrap = s.DocumentChange(document, 1, 2**64-1, 1, (
            s.DocumentAssign('value', -(2**63)), s.DocumentAssign('body', s.DocumentKind.TEXT),
            s.DocumentInsert(s.DocumentDot(2, 2**64-1), s.DocumentCharacter('🙂'))))
        assert s.prepare_document(bootstrap).data.hex() == cfg['changes'][0]
        for invalid in ('', 'é', '\ud800'):
            try: s.DocumentCharacter(invalid)
            except (ValueError, UnicodeError): pass
            else: raise AssertionError('Not a single Unicode scalar')
        print('Document Python codecs passed', flush=True)
        return
    class Bytes:
        type_id, version, max_encoded_bytes = 'test.document.tick', 1, 32
        def encode(self, value): return value
        def decode(self, value): return value
    class Handler:
        phase = None
        escaped = None
        def initialize(self, turn):
            turn.document(document).create()
        def handle(self, turn, incoming):
            self.escaped = turn.document(document)
            value = incoming.value
            if value == b'initialize': return
            if value in (b'0', b'1'):
                index = int(value)
                change = s.PreparedDocumentChange(document, bytes.fromhex(cfg['changes'][index]))
                progress = self.escaped.stage(index+1, change, node_limit=256)
                self.phase = progress.phase.value
                assert (progress.revision is None) == (progress.phase is s.DocumentPhase.PROGRESS)
            elif value == b'checkpoint': self.phase = self.escaped.checkpoint(90).phase.value
            elif value == b'window': self.escaped.merge_window(2)
            elif value == b'retire': self.escaped.retire()
            else: raise AssertionError(value)
    config = s.ServiceConfig(cfg['url'], cfg['profile'], s.Activation(ProcessRef(cfg['realm'], cfg['pid']),
        cfg['principal'], cfg['generation'], Path(cfg['seed_file'])), timeout_ms=15000)
    handler = Handler()
    runner = s.Runner(config, handler=handler, codec=Bytes(), failure_policy=s.FailurePolicy.STOP, recovery=s.Recovery.fence_on_restart())
    saved = None
    try:
        for line in sys.stdin:
            mode = line.strip()
            if mode == 'close': break
            if mode == 'one':
                handler.phase = None
                for _ in range(12):
                    result = runner.next()
                    if isinstance(result, s.Committed): break
                    assert isinstance(result, s.Progress), result
                else: raise AssertionError('No commit')
                if handler.escaped:
                    from transit_client.errors import TurnExpired
                    try: handler.escaped.retire()
                    except TurnExpired: pass
                    else: raise AssertionError('Escaped Document owner remained usable')
                output = {'event': 'committed', 'phase': handler.phase}
            elif mode in ('read', 'old', 'denied', 'retired'):
                if mode == 'read':
                    description = runner.documents.describe(resource, document)
                    reference = description.reference
                    assert description.floor == description.merge_window == 0
                    field = runner.documents.path(reference, ('value',)).field
                    page = runner.documents.sequence(reference, s.DocumentDot(2, 2**64-1))
                    assert page.next is None
                    chars = ''.join(item.field.assignments[0].value.value for item in page.items)
                    assert chars == ('🙂' if reference.revision == 2 else '🙂́')
                    assert field.assignments[0].value == -(2**63)
                    assert runner.documents.path(reference, ('missing',)).field.status is s.DocumentStatus.MISSING
                    accepted = runner.documents.accepted_change(reference)
                    assert s.prepare_document(accepted).data.hex() == cfg['changes'][reference.revision-2]
                    saved = saved or reference
                    output = {'revision': str(reference.revision), 'items': len(page.items), 'status': field.status.value}
                elif mode == 'old':
                    assert runner.documents.path(saved, ('value',)).field.status is s.DocumentStatus.SCALAR
                    output = {'retained': True}
                elif mode == 'denied':
                    try: runner.documents.path(saved, ('value',))
                    except AccessDenied: output = {'denied': True}
                    else: raise AssertionError('Revoked Document read succeeded')
                else:
                    assert runner.documents.describe(resource, document).retired
                    try: runner.documents.path(saved, ('value',))
                    except TransitError as error:
                        assert error.code == 'DocumentRetired', error
                        output = {'retired': True}
                    else: raise AssertionError('Retired Document read succeeded')
            elif mode == 'resynchronize':
                result = runner.documents.resynchronize(resource, document, 2**64-1)
                assert result.reference.revision == 3
                output = {'previous': str(result.previous_counter), 'clock': str(result.clock)}
            elif mode == 'async-close':
                async def asynchronous():
                    other = await s.AsyncRunner.open(config, handler=Handler(), codec=Bytes(), failure_policy=s.FailurePolicy.STOP, recovery=s.Recovery.fence_on_restart())
                    read = other.documents
                    task = asyncio.create_task(read.describe(resource, document))
                    await asyncio.sleep(0)
                    task.cancel()
                    try: await task
                    except asyncio.CancelledError: pass
                    await other.aclose()
                    try: await read.describe(resource, document)
                    except Closed: pass
                    else: raise AssertionError('Read survived runner destruction')
                asyncio.run(asynchronous())
                output = {'joined': True}
            else: raise AssertionError(mode)
            print(json.dumps(output), flush=True)
    finally:
        runner.close()
    print(json.dumps({'closed': True}), flush=True)



def run(node, cli, raw_library, wheels, http_worker=None, *, execute=None):
    if execute is None and http_worker is None:
        raise ValueError("The full Station SDK schedule requires the HTTP worker binary")
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
    (execute or schedule)(node, cli, raw_library, install, 'Python')
    if execute is None:
        from sdk_http_runner import run as http_schedule
        http_schedule(node, cli, raw_library, http_worker, install, 'Python', public_release=True, public_followup=True)

if __name__ == '__main__':
    if sys.argv[1] == '--consumer': consumer(*sys.argv[2:])
    else: run(*sys.argv[1:])
