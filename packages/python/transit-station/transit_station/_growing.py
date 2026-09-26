"""Private synchronous bridge; the public runner owns its worker and lifetime."""
from __future__ import annotations
import ctypes as c
from pathlib import Path
import time
from typing import Any
import transit_client
from transit_client import OperationIdentity
from transit_client._native import Library, encode, seed
from transit_client.errors import IncompatibleNative, TurnExpired, UnsupportedCapability, native_error
from .models import FailurePolicy, FrozenMutation, ServiceConfig


class Growing:
    def __init__(self, config: ServiceConfig, policy: FailurePolicy) -> None:
        self.api = Library('station', Path(__file__).with_name('station-abi.json'), config.native_directory)
        self.raw = Library('client', Path(transit_client.__file__).with_name('client-abi.json'), config.native_directory)
        self.caps: dict[str, Any] = self.api.call('station_growing_capabilities')
        if self.caps.get('version') != 1 or self.caps.get('profile') != 'growing_v3' or not all(self.caps.get(name) for name in ('gated_dispatch', 'retained_confirmation', 'scoped_turns', 'paged_state', 'tables', 'retained_sources')):
            raise UnsupportedCapability('Native Station lacks the required growing turn capabilities')
        if config.query_results and not self.caps['query_results']:
            raise UnsupportedCapability('Native Station does not support growing query results')
        if len(config.association.encode()) > self.caps['key_bytes']:
            raise ValueError('Association exceeds the growing name bound')
        activation = config.activation
        endpoint, key = config.url.encode(), seed(activation.seed_file)
        self.handle = c.c_void_p()
        try:
            self._authority(config, endpoint, key)
            document = encode({'profile': config.profile, 'realm': activation.process.realm,
                               'principal': activation.principal, 'pid': activation.process.pid,
                               'generation': activation.generation, 'association': config.association,
                               'timeout_ms': config.timeout_ms, 'failure_policy': policy.value,
                               'query_results': config.query_results})
            status = self.api.lib.station_growing_create(1, endpoint, len(endpoint), key,
                                                        document, len(document), c.byref(self.handle))
            if status:
                raise native_error(status, phase='open_runner')
        finally:
            c.memset(key, 0, 32)

    def _authority(self, config: ServiceConfig, endpoint: bytes, key: c.Array[c.c_char]) -> None:
        """Read advertised primitives; the broad Station family stays unadvertised."""
        client, operation = c.c_void_p(), c.c_void_p()
        try:
            status = self.raw.lib.transit_client_create(1, endpoint, len(endpoint), config.timeout_ms, c.byref(client))
            if status:
                raise native_error(status, phase='authority_capabilities')
            document = encode({'realm': config.activation.process.realm, 'principal': config.activation.principal,
                               'kind': {'capabilities': {}}})
            status = self.raw.lib.transit_operation_prepare(7, key, document, len(document), c.byref(operation))
            if status:
                raise native_error(status, phase='authority_capabilities')
            result = self.raw.call('transit_client_call', client, operation)['body']['capabilities']
            if result['version'] != 3 or result['profile'] != 'growing_v1' or not all(result[name] for name in ('association_lookup', 'scoped_retry', 'retained_read_versions')):
                raise UnsupportedCapability('Authority lacks required growing state/recovery primitives')
        finally:
            self.raw.lib.transit_operation_destroy(operation)
            self.raw.lib.transit_client_destroy(client)

    def prepare(self) -> dict[str, Any]:
        result: dict[str, Any] = self.api.call('station_growing_prepare', self.handle, time.time_ns() // 1_000_000 + 30000)
        return result

    def apply(self, scope: int, action: object) -> Any:
        data = encode(action)
        return self.api.call('station_growing_apply', self.handle, scope, data, len(data))

    def http_read(self, action: object) -> dict[str, Any]:
        if not self.caps.get('http_replay'):
            raise UnsupportedCapability('Native Station lacks HTTP replay support')
        data = encode(action)
        result: dict[str, Any] = self.api.call('station_growing_http_read', self.handle, data, len(data))
        return result

    def finish(self, scope: int, failed: bool) -> None:
        self.api.call('station_growing_finish_result', self.handle, scope, int(failed))

    def discard(self, scope: int) -> None:
        status = self.api.lib.station_growing_discard(self.handle, scope)
        if status:
            raise native_error(status, phase='discard')

    def pending(self, event: dict[str, Any]) -> FrozenMutation:
        frozen = self.api.call_bytes('station_growing_pending', self.handle)
        if frozen is None:
            raise IncompatibleNative('Native Station returned no pending mutation')
        pointer = c.c_void_p()
        status = self.raw.lib.transit_operation_import(frozen, len(frozen), c.byref(pointer))
        if status:
            raise native_error(status, phase='pending_metadata')
        try:
            metadata = self.raw.call('transit_operation_metadata', pointer)
        finally:
            self.raw.lib.transit_operation_destroy(pointer)
        purpose = event['pending_kind']
        if metadata['kind'] != 'growing_command' or metadata['profile'] != 'growing_v3' or metadata['command'] not in {'permit': ('begin_turn',), 'open': ('open_view',), 'commit': ('turn', 'turn_with_versions')}[purpose]:
            raise IncompatibleNative('Native pending mutation has an incompatible purpose')
        return FrozenMutation(OperationIdentity(metadata['identity']), purpose, event['pending_input'], frozen)

    def dispatch(self, frozen: FrozenMutation) -> dict[str, Any]:
        result: dict[str, Any] = self.api.call('station_growing_dispatch', self.handle, recovery=frozen.export())
        return result

    def confirmation(self, frozen: FrozenMutation) -> dict[str, Any] | None:
        try:
            result: dict[str, Any] = self.api.call('station_growing_confirmation', self.handle)
        except TurnExpired:
            return None
        confirmed = result['confirmation']
        return result if (confirmed['kind'], confirmed['input']) == (frozen.purpose, frozen.input_position) else None

    def close(self) -> None:
        self.api.lib.station_growing_destroy(self.handle)
        self.handle = c.c_void_p()
