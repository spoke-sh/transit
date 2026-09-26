"""Sequential handlers and explicit recovery gates over the shared native machine."""
from __future__ import annotations
import asyncio
import inspect
import json
from pathlib import Path
import threading
from typing import Any, AsyncIterator, Callable, Generic, Iterator, Protocol, TypeVar, cast
from transit_client import MutationReceipt, ProcessRef
from transit_client._worker import Worker, owned_await
from transit_client.errors import Busy, Closed, HandlerError, TransitError, UncertainOperation
from ._growing import Growing
from .models import (Blocked, Call, Cast, Codec, Committed, Control, FailurePolicy, FrozenMutation,
                     Idle, Incoming, NeedsRecovery, Origin, Progress, Recovery, Reply, RunnerEvent,
                     ServiceConfig, Stopped, decoded)
from .query import ResultReader
from .turn import Turn

M = TypeVar('M')


class Handler(Protocol[M]):
    def initialize(self, turn: Turn) -> None: ...
    def handle(self, turn: Turn, incoming: Incoming[M]) -> None: ...


class StopSignal(Protocol):
    def is_set(self) -> bool: ...


def _synchronous(value: object) -> None:
    if inspect.isawaitable(value):
        if inspect.iscoroutine(value):
            value.close()
        raise HandlerError('Handlers and persistence hooks must be synchronous')
    if value is not None:
        raise HandlerError('Handlers and persistence hooks must return None')


def _invoke(callback: Callable[..., object], *args: object) -> None:
    _synchronous(callback(*args))


def _origin(realm: int, value: dict[str, Any]) -> Origin:
    if 'process' in value:
        item = value['process']
        return Origin('process', process=ProcessRef(realm, item['pid']), turn=item['turn'], output=item['output'])
    if 'external' in value:
        item = value['external']
        return Origin('external', principal=item['principal'], policy_revision=item['policy_revision'])
    item = value['effect']
    return Origin('effect', effect=item['id'], attempt=item['attempt'], executor=item['executor'])


class Runner(Generic[M]):
    def _setup(self, config: ServiceConfig, handler: Handler[M], codec: Codec[M], policy: FailurePolicy, recovery: Recovery) -> None:
        if not isinstance(config, ServiceConfig) or not isinstance(policy, FailurePolicy) or not isinstance(recovery, Recovery):
            raise TypeError('Select explicit service configuration, failure policy and recovery policy')
        if not callable(getattr(handler, 'initialize', None)) or not callable(getattr(handler, 'handle', None)):
            raise TypeError('Handler must implement initialize and handle')
        self.config, self._handler, self._codec, self._policy, self._recovery = config, handler, codec, policy, recovery
        contract = json.loads(Path(__file__).with_name('station-abi.json').read_bytes())
        self._worker = Worker(contract['minimum_stack_bytes'])
        self._native: Growing | None = None
        self._pending: FrozenMutation | None = None
        self._confirmed: dict[str, Any] | None = None
        self._paused: NeedsRecovery | None = None
        self._attempted = False
        self._stop = threading.Event()
        self._external_stop: StopSignal | None = None
        self._iteration_lock = threading.Lock()
        self._iteration: object | None = None
        self._last_event: RunnerEvent | None = None

    def __init__(self, config: ServiceConfig, *, handler: Handler[M], codec: Codec[M],
                 failure_policy: FailurePolicy, recovery: Recovery) -> None:
        self._setup(config, handler, codec, failure_policy, recovery)
        try:
            self._worker.call(self._open)
        except BaseException:
            self._worker.close(self._destroy)
            raise

    @classmethod
    def open(cls, config: ServiceConfig, *, handler: Handler[M], codec: Codec[M],
             failure_policy: FailurePolicy, recovery: Recovery) -> Runner[M]:
        return cls(config, handler=handler, codec=codec, failure_policy=failure_policy, recovery=recovery)

    def _open(self) -> None:
        self._native = Growing(self.config, self._policy)

    def is_set(self) -> bool:
        return self._stop.is_set() or (self._external_stop is not None and self._external_stop.is_set())

    def stop(self) -> None:
        self._stop.set()

    @property
    def last_event(self) -> RunnerEvent | None:
        return self._last_event

    @property
    def pending(self) -> FrozenMutation | None:
        return self._pending

    def _owner(self, stop: StopSignal | None) -> object:
        with self._iteration_lock:
            if self._iteration is not None:
                raise Busy('Runner already has a consumer')
            token = object()
            self._iteration, self._external_stop = token, stop
            return token

    def _release(self, token: object) -> None:
        with self._iteration_lock:
            if self._iteration is token:
                self._iteration, self._external_stop = None, None

    def _public(self, function: Callable[[], RunnerEvent]) -> RunnerEvent:
        with self._iteration_lock:
            if self._iteration is not None:
                raise Busy('Runner already has a consumer')
            future = self._worker.submit(function)
        return future.result()

    def next(self) -> RunnerEvent:
        return self._public(self._next)

    def reconcile(self) -> RunnerEvent:
        return self._public(self._reconcile)

    def _record(self, event: RunnerEvent) -> RunnerEvent:
        self._last_event = event
        return event

    def _pause(self, error: Exception, phase: str, receipt: MutationReceipt | None = None) -> NeedsRecovery:
        assert self._pending is not None
        self._paused = NeedsRecovery(self._pending, phase, error, receipt)
        self._last_event = self._paused
        return self._paused

    def _accept(self, result: dict[str, Any]) -> RunnerEvent:
        assert self._pending is not None
        self._confirmed = result
        native = result['confirmation']
        if native is None or (native['kind'], native['input']) != (self._pending.purpose, self._pending.input_position):
            return self._pause(TransitError('Confirmation does not match the saved mutation'), 'confirm')
        receipt = MutationReceipt(native['receipt']['position'])
        store = self._recovery.store
        if store is not None:
            try:
                _invoke(store.confirmed, self._pending.identity, receipt)
            except Exception as error:
                return self._pause(error, 'confirm', receipt)
        event: RunnerEvent
        if result['event'] == 'blocked':
            event = Blocked(native['input'], receipt)
        elif self._pending.purpose == 'commit':
            event = Committed(native['input'], receipt)
        else:
            event = Progress()
        self._pending = self._confirmed = self._paused = None
        self._attempted = False
        return self._record(event)

    def _attempt(self) -> RunnerEvent:
        assert self._native is not None and self._pending is not None
        if self._confirmed is not None:
            return self._accept(self._confirmed)
        if self._attempted:
            try:
                known = self._native.confirmation(self._pending)
            except Exception as error:
                return self._pause(error, 'observe-confirmation')
            if known is not None:
                return self._accept(known)
        if self.is_set():
            return self._record(Stopped())
        if self._recovery.store is not None:
            try:
                _invoke(self._recovery.store.before_dispatch, self._pending)
            except Exception as error:
                return self._pause(error, 'persist')
        if self.is_set():
            return self._record(Stopped())
        self._attempted = True
        try:
            result = self._native.dispatch(self._pending)
        except Exception as error:
            if not isinstance(error, TransitError):
                error = UncertainOperation(recovery=self._pending.export(), code=type(error).__name__)
            return self._pause(error, 'dispatch')
        return self._accept(result)

    def _reconcile(self) -> RunnerEvent:
        if self._pending is None:
            raise Closed('There is no saved mutation to reconcile')
        return self._attempt()

    def _handle(self, event: dict[str, Any]) -> RunnerEvent:
        assert self._native is not None
        turn = Turn(self._native, event, self.config.activation.process, self)
        if self.is_set():
            turn._end()
            self._native.discard(turn._scope)
            return self._record(Stopped())
        failure: Exception | None = None
        try:
            message = event['input']
            kind, position = message['kind'], message['position']
            origin = _origin(self.config.activation.process.realm, message['origin'])
            correlation = int(message['correlation'])
            if kind in ('cast', 'call', 'reply'):
                value = decoded(self._codec, bytes.fromhex(message['payload']), self._native.caps['message_bytes'])
                incoming: Incoming[M]
                if kind == 'cast': incoming = Cast(value, position, origin)
                elif kind == 'call': incoming = Call(value, position, origin, correlation)
                else: incoming = Reply(value, position, origin, correlation)
                if event['initializing']:
                    _invoke(self._handler.initialize, turn)
                _invoke(self._handler.handle, turn, incoming)
            elif kind == 'result_complete':
                callback = getattr(self._handler, 'handle_result', None)
                if not callable(callback):
                    raise HandlerError('A verified query result requires handle_result')
                if event['initializing']:
                    _invoke(self._handler.initialize, turn)
                _synchronous(callback(turn, ResultReader(turn, correlation)))
            elif kind in ('timeout', 'cancel'):
                callback = getattr(self._handler, 'handle_control', None)
                if not callable(callback):
                    raise HandlerError('A framework control input requires handle_control')
                if event['initializing']:
                    _invoke(self._handler.initialize, turn)
                _synchronous(callback(turn, Control(kind, position, origin, correlation)))
            else:
                raise HandlerError('Unsupported native application input')
        except Exception as error:
            failure = error
        except BaseException:
            self._native.discard(turn._scope)
            raise
        finally:
            turn._end()
        if self.is_set():
            self._native.discard(turn._scope)
            return self._record(Stopped())
        try:
            self._native.finish(turn._scope, failure is not None)
        except TransitError as error:
            if failure is not None and self._policy is FailurePolicy.STOP and error.code == 'ForeignHandlerFailure':
                raise failure from None
            raise
        return Progress()

    def _next(self) -> RunnerEvent:
        if self._paused is not None:
            return self._paused
        if self.is_set():
            return self._record(Stopped())
        if self._pending is not None:
            return self._attempt()
        assert self._native is not None
        # Bound reads/framework preparation per call; run owns the continuation.
        for _ in range(16):
            if self.is_set():
                return self._record(Stopped())
            event = self._native.prepare()
            if event['event'] == 'pending':
                self._pending = self._native.pending(event)
                return self._attempt()
            if event['event'] == 'idle':
                return self._record(Idle())
            if event['event'] == 'blocked':
                return self._record(Blocked(None, None))
            if event['event'] == 'ready':
                outcome = self._handle(event)
                if isinstance(outcome, Stopped):
                    return outcome
            elif event['event'] != 'progress':
                raise TransitError('Unexpected native preparation event')
        return self._record(Progress())

    def run(self, *, stop: StopSignal | None = None) -> Iterator[RunnerEvent]:
        token = self._owner(stop)
        try:
            while True:
                event = self._worker.call(self._next)
                if isinstance(event, (NeedsRecovery, Blocked, Stopped)):
                    self._release(token)
                    yield event
                    return
                if isinstance(event, Committed):
                    yield event
                elif isinstance(event, Idle):
                    self._stop.wait(0.02)
        finally:
            self._release(token)

    def _destroy(self) -> None:
        if self._native is not None:
            self._native.close()
            self._native = None

    def close(self) -> None:
        self._worker.begin_close(self._destroy)  # Reject callback reentry before setting stop.
        self.stop()
        self._worker.close(self._destroy)

    def __enter__(self) -> Runner[M]: return self
    def __exit__(self, *_: object) -> None: self.close()


class AsyncRunner(Generic[M]):
    def __init__(self, runner: Runner[M]) -> None:
        self._runner = runner

    @classmethod
    async def open(cls, config: ServiceConfig, *, handler: Handler[M], codec: Codec[M],
                   failure_policy: FailurePolicy, recovery: Recovery) -> AsyncRunner[M]:
        runner = cast(Runner[M], Runner.__new__(Runner))
        runner._setup(config, handler, codec, failure_policy, recovery)
        try:
            await owned_await(runner._worker.submit(runner._open))
        except BaseException:
            runner.stop()
            await runner._worker.aclose(runner._destroy)
            raise
        return cls(runner)

    async def _public(self, function: Callable[[], RunnerEvent]) -> RunnerEvent:
        with self._runner._iteration_lock:
            if self._runner._iteration is not None:
                raise Busy('Runner already has a consumer')
            future = self._runner._worker.submit(function)
        try:
            return await owned_await(future)
        except asyncio.CancelledError:
            self._runner.stop()
            raise

    async def next(self) -> RunnerEvent: return await self._public(self._runner._next)
    async def reconcile(self) -> RunnerEvent: return await self._public(self._runner._reconcile)
    def stop(self) -> None: self._runner.stop()
    @property
    def last_event(self) -> RunnerEvent | None: return self._runner.last_event
    @property
    def pending(self) -> FrozenMutation | None: return self._runner.pending

    async def run(self, *, stop: StopSignal | None = None) -> AsyncIterator[RunnerEvent]:
        token = self._runner._owner(stop)
        try:
            while True:
                event = await owned_await(self._runner._worker.submit(self._runner._next))
                if isinstance(event, (NeedsRecovery, Blocked, Stopped)):
                    self._runner._release(token)
                    yield event
                    return
                if isinstance(event, Committed):
                    yield event
                elif isinstance(event, Idle):
                    await asyncio.sleep(0.02)
        except asyncio.CancelledError:
            self._runner.stop()
            raise
        finally:
            self._runner._release(token)

    async def aclose(self) -> None:
        self._runner._worker.begin_close(self._runner._destroy)
        self._runner.stop()
        await self._runner._worker.aclose(self._runner._destroy)

    async def __aenter__(self) -> AsyncRunner[M]: return self
    async def __aexit__(self, *_: object) -> None: await self.aclose()
