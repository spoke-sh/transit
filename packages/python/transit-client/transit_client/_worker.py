"""One owned worker, one admitted operation, one joined close; no executor queue."""
from __future__ import annotations
import asyncio
from concurrent.futures import Future
from queue import Queue
import threading
from typing import Callable, TypeVar, cast
from .errors import Busy, Closed

T = TypeVar('T')
_STACK_LOCK = threading.Lock()


class Worker:
    def __init__(self, minimum_stack_bytes: int) -> None:
        self._lock = threading.Lock()
        self._queue: Queue[tuple[Callable[[], object], Future[object]] | None] = Queue(1)
        self._busy = self._closing = False
        self._cleanup: Callable[[], None] = lambda: None
        self._closed: Future[None] = Future()
        self._thread = threading.Thread(target=self._run, name='transit-sdk', daemon=True)
        # Python exposes stack selection globally. Serialize SDK starts, raise
        # the stack only for thread construction, then restore the host setting.
        with _STACK_LOCK:
            before = threading.stack_size()
            threading.stack_size(max(before, minimum_stack_bytes))
            try:
                self._thread.start()
            finally:
                threading.stack_size(before)

    def _run(self) -> None:
        try:
            while True:
                job = self._queue.get()
                if job is None:
                    break
                function, future = job
                result, failure = None, None
                try:
                    result = function()
                except BaseException as error:
                    failure = error
                with self._lock:
                    self._busy = False
                if failure is None:
                    future.set_result(result)
                else:
                    future.set_exception(failure)
                with self._lock:
                    if self._closing and not self._busy:
                        break
            self._cleanup()
        except BaseException as error:
            self._closed.set_exception(error)
        else:
            self._closed.set_result(None)

    def submit(self, function: Callable[[], T]) -> Future[T]:
        with self._lock:
            if self._closing:
                raise Closed('Client or runner is closing')
            if self._busy:
                raise Busy('One operation per client or runner')
            future: Future[T] = Future()
            self._busy = True
            self._queue.put_nowait((function, cast(Future[object], future)))
            return future

    def call(self, function: Callable[[], T]) -> T:
        return self.submit(function).result()

    def begin_close(self, cleanup: Callable[[], None]) -> Future[None]:
        if threading.current_thread() is self._thread:
            raise Busy('A handler or callback cannot close its own worker')
        with self._lock:
            if not self._closing:
                self._cleanup, self._closing = cleanup, True
                if not self._busy:
                    self._queue.put_nowait(None)
        return self._closed

    def close(self, cleanup: Callable[[], None]) -> None:
        self.begin_close(cleanup).result()
        self._thread.join()

    async def aclose(self, cleanup: Callable[[], None]) -> None:
        # Closing cannot abandon native ownership when the awaiting task is
        # cancelled again. The worker exits after releasing all native handles.
        future = asyncio.wrap_future(self.begin_close(cleanup))
        cancelled = False
        while not future.done():
            try:
                await asyncio.shield(future)
            except asyncio.CancelledError:
                cancelled = True
        future.result()
        self._thread.join()
        if cancelled:
            raise asyncio.CancelledError


async def owned_await(future: Future[T]) -> T:
    return await asyncio.shield(asyncio.wrap_future(future))
