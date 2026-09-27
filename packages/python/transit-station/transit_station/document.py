"""Document values and bounded reads. The shared Zig service owns merge semantics."""
from __future__ import annotations
from dataclasses import dataclass, field as dataclass_field
from enum import Enum
from pathlib import Path
import struct
from typing import Any, Awaitable, Callable, TYPE_CHECKING
from transit_client import ResourceRef
from transit_client._native import Library, encode
from transit_client._worker import Worker
from transit_client.errors import IncompatibleNative, UnsupportedCapability
from transit_client.types import integer, owned_bytes
if TYPE_CHECKING:
    from .turn import Turn

U64_MAX = (1 << 64) - 1


def _uint(value: int, name: str, minimum: int = 0) -> int:
    return integer(value, name, minimum=minimum, maximum=U64_MAX)


def _codec(action: object, directory: Path | None) -> dict[str, Any]:
    api = Library('station', Path(__file__).with_name('station-abi.json'), directory)
    worker = Worker(api.contract['minimum_stack_bytes'])
    try:
        data = encode(action)
        def call() -> dict[str, Any]:
            if not api.call('station_growing_capabilities').get('document_codecs'):
                raise UnsupportedCapability('Native Station lacks Document codecs')
            result: dict[str, Any] = api.call('station_document_codec', data, len(data))
            return result
        return worker.call(call)
    finally:
        worker.close(lambda: None)


@dataclass(frozen=True, slots=True)
class DocumentDot:
    counter: int = 0
    replica: int = 0
    def __post_init__(self) -> None:
        _uint(self.counter, 'counter'); _uint(self.replica, 'replica')
        if (self.counter == 0) != (self.replica == 0): raise ValueError('Root has both identities zero')
    def _wire(self) -> object: return {'counter': str(self.counter), 'replica': str(self.replica)}


class DocumentKind(Enum):
    MAP = 'map'
    LIST = 'list'
    TEXT = 'text'


@dataclass(frozen=True, slots=True)
class DocumentUnsigned:
    value: int
    def __post_init__(self) -> None: _uint(self.value, 'unsigned scalar')


@dataclass(frozen=True, slots=True)
class DocumentCharacter:
    value: str
    def __post_init__(self) -> None:
        if not isinstance(self.value, str) or len(self.value) != 1: raise ValueError('Expected one Unicode scalar')
        self.value.encode('utf-8', errors='strict')


type DocumentValue = None | bool | int | float | str | bytes | DocumentKind | DocumentUnsigned | DocumentCharacter


def _value(value: DocumentValue) -> object:
    if value is None: return {'null_value': {}}
    if type(value) is bool: return {'boolean': value}
    if type(value) is int: return {'signed': str(integer(value, 'signed scalar', minimum=-(1 << 63), maximum=(1 << 63)-1))}
    if type(value) is float: return {'float_bits': struct.pack('<d', value).hex()}
    if isinstance(value, str): return {'string': value}
    if isinstance(value, bytes): return {'binary': owned_bytes(value, 96).hex()}
    if isinstance(value, DocumentKind): return {value.value: {}}
    if isinstance(value, DocumentUnsigned): return {'unsigned': str(value.value)}
    if isinstance(value, DocumentCharacter): return {'character': value.value}
    raise TypeError('Expected a Document scalar or object kind')


def _from_value(value: dict[str, Any]) -> DocumentValue:
    if len(value) != 1: raise IncompatibleNative('Invalid Document value')
    kind, payload = next(iter(value.items()))
    if kind == 'null_value': return None
    if kind == 'boolean':
        if type(payload) is not bool: raise IncompatibleNative('Invalid Document boolean')
        return payload
    if kind == 'signed': return integer(int(payload), 'signed scalar', minimum=-(1 << 63), maximum=(1 << 63)-1)
    if kind == 'unsigned': return DocumentUnsigned(int(payload))
    if kind == 'float_bits':
        result: float = struct.unpack('<d', bytes.fromhex(payload))[0]
        return result
    if kind == 'string':
        if not isinstance(payload, str): raise IncompatibleNative('Invalid Document string')
        return payload
    if kind == 'binary': return owned_bytes(bytes.fromhex(payload), 96)
    if kind == 'character': return DocumentCharacter(payload)
    return DocumentKind(kind)


def _dots(values: tuple[DocumentDot, ...]) -> list[object]:
    if not isinstance(values, tuple) or len(values) > 8 or not all(isinstance(v, DocumentDot) for v in values):
        raise TypeError('Expected up to eight immutable observed operation identities')
    return [v._wire() for v in values]


@dataclass(frozen=True, slots=True)
class DocumentAssign:
    field: str
    value: DocumentValue = dataclass_field(repr=False)
    object_id: DocumentDot = DocumentDot()
    observed: tuple[DocumentDot, ...] = ()
    def _wire(self) -> object:
        return {'assign': {'object': self.object_id._wire(), 'field': self.field, 'observed': _dots(self.observed), 'value': _value(self.value)}}


@dataclass(frozen=True, slots=True)
class DocumentRemove:
    field: str
    observed: tuple[DocumentDot, ...]
    object_id: DocumentDot = DocumentDot()
    def _wire(self) -> object: return {'remove': {'object': self.object_id._wire(), 'field': self.field, 'observed': _dots(self.observed)}}


@dataclass(frozen=True, slots=True)
class DocumentInsert:
    object_id: DocumentDot
    value: DocumentValue = dataclass_field(repr=False)
    after: DocumentDot = DocumentDot()
    def _wire(self) -> object: return {'insert': {'object': self.object_id._wire(), 'after': self.after._wire(), 'value': _value(self.value)}}


@dataclass(frozen=True, slots=True)
class DocumentSetElement:
    object_id: DocumentDot
    element: DocumentDot
    observed: tuple[DocumentDot, ...]
    value: DocumentValue = dataclass_field(repr=False)
    def _wire(self) -> object:
        return {'set_element': {'object': self.object_id._wire(), 'element': self.element._wire(), 'observed': _dots(self.observed), 'value': _value(self.value)}}


@dataclass(frozen=True, slots=True)
class DocumentDeleteElement:
    object_id: DocumentDot
    element: DocumentDot
    def _wire(self) -> object: return {'delete_element': {'object': self.object_id._wire(), 'element': self.element._wire()}}


type DocumentOperation = DocumentAssign | DocumentRemove | DocumentInsert | DocumentSetElement | DocumentDeleteElement


def _dot(v: dict[str, Any]) -> DocumentDot: return DocumentDot(int(v['counter']), int(v['replica']))


def _operation(value: dict[str, Any]) -> DocumentOperation:
    kind, v = next(iter(value.items()))
    obj = _dot(v['object'])
    observed = tuple(_dot(dot) for dot in v.get('observed', ()))
    if kind == 'assign': return DocumentAssign(v['field'], _from_value(v['value']), obj, observed)
    if kind == 'remove': return DocumentRemove(v['field'], observed, obj)
    if kind == 'insert': return DocumentInsert(obj, _from_value(v['value']), _dot(v['after']))
    if kind == 'set_element': return DocumentSetElement(obj, _dot(v['element']), observed, _from_value(v['value']))
    if kind == 'delete_element': return DocumentDeleteElement(obj, _dot(v['element']))
    raise IncompatibleNative('Invalid Document operation')


@dataclass(frozen=True, slots=True)
class DocumentChange:
    document: int
    epoch: int
    replica: int
    first: int
    operations: tuple[DocumentOperation, ...] = dataclass_field(repr=False)
    previous: int = 0
    type_revision: int = 1
    def _wire(self) -> object:
        if not isinstance(self.operations, tuple) or not 1 <= len(self.operations) <= 8:
            raise TypeError('Expected one to eight immutable operations')
        return {'document': str(_uint(self.document, 'Document ID', 1)), 'epoch': str(_uint(self.epoch, 'epoch', 1)),
            'type_revision': integer(self.type_revision, 'type revision', maximum=(1 << 32)-1),
            'replica': str(_uint(self.replica, 'replica', 1)), 'first': str(_uint(self.first, 'first', 1)),
            'previous': str(_uint(self.previous, 'previous')), 'operations': [op._wire() for op in self.operations]}


def _change(v: dict[str, Any]) -> DocumentChange:
    return DocumentChange(int(v['document']), int(v['epoch']), int(v['replica']), int(v['first']),
                          tuple(_operation(op) for op in v['operations']), int(v['previous']), v['type_revision'])


@dataclass(frozen=True, slots=True)
class PreparedDocumentChange:
    """Canonical tentative bytes. Preparation is not durable acceptance."""
    document: int
    data: bytes = dataclass_field(repr=False)
    def __post_init__(self) -> None:
        _uint(self.document, 'Document ID', 1)
        owned_bytes(self.data, 4096)


def prepare_document(change: DocumentChange, *, native_directory: Path | None = None) -> PreparedDocumentChange:
    if not isinstance(change, DocumentChange): raise TypeError('Expected DocumentChange')
    value = _codec({'prepare': change._wire()}, native_directory)['prepared']
    return PreparedDocumentChange(change.document, bytes.fromhex(value['bytes']))


def decode_document(data: bytes, *, native_directory: Path | None = None) -> DocumentChange:
    return _change(_codec({'decode': owned_bytes(data, 4096).hex()}, native_directory)['change'])


@dataclass(frozen=True, slots=True)
class DocumentReference:
    resource: ResourceRef
    document: int
    epoch: int
    type_revision: int
    revision: int
    def __post_init__(self) -> None:
        if not isinstance(self.resource, ResourceRef): raise TypeError('Expected ResourceRef')
        _uint(self.document, 'Document ID', 1); _uint(self.epoch, 'epoch', 1); _uint(self.revision, 'revision')
        integer(self.type_revision, 'type revision', maximum=(1 << 32)-1)
    def encode(self, *, native_directory: Path | None = None) -> bytes:
        return bytes.fromhex(_codec({'reference': {'resource': self.resource.resource,
            'document': str(self.document), 'epoch': str(self.epoch), 'type_revision': self.type_revision,
            'revision': str(self.revision)}}, native_directory)['reference'])
    @classmethod
    def decode(cls, realm: int, data: bytes, *, native_directory: Path | None = None) -> DocumentReference:
        v = _codec({'inspect_reference': owned_bytes(data, 40).hex()}, native_directory)['inspected_reference']
        return cls(ResourceRef(realm, v['resource']), int(v['document']), int(v['epoch']), v['type_revision'], int(v['revision']))


class DocumentStatus(Enum):
    MISSING = 'missing'
    NULL = 'null_value'
    SCALAR = 'scalar'
    OBJECT = 'object'
    CONFLICT = 'conflict'


@dataclass(frozen=True, slots=True)
class DocumentAssignment:
    id: DocumentDot
    value: DocumentValue = dataclass_field(repr=False)


@dataclass(frozen=True, slots=True)
class DocumentField:
    status: DocumentStatus
    assignments: tuple[DocumentAssignment, ...] = dataclass_field(repr=False)
    @property
    def observed(self) -> tuple[DocumentDot, ...]: return tuple(value.id for value in self.assignments)


def _register(v: dict[str, Any]) -> DocumentField:
    values = tuple(DocumentAssignment(_dot(a['id']), _from_value(a['value'])) for a in v['assignments'])
    status = DocumentStatus(v['status'])
    if len(values) > 8 or (status is DocumentStatus.MISSING) != (len(values) == 0) or (status is DocumentStatus.CONFLICT) != (len(values) > 1):
        raise IncompatibleNative('Inconsistent Document field')
    return DocumentField(status, values)


@dataclass(frozen=True, slots=True)
class DocumentDescription:
    reference: DocumentReference
    source_revision: int
    floor: int
    merge_window: int
    retired: bool
    active_job: int
    change_format: int


@dataclass(frozen=True, slots=True)
class DocumentPath:
    reference: DocumentReference
    source_revision: int
    field: DocumentField


@dataclass(frozen=True, slots=True)
class DocumentItem:
    id: DocumentDot
    field: DocumentField


@dataclass(frozen=True, slots=True)
class DocumentPage:
    reference: DocumentReference
    source_revision: int
    items: tuple[DocumentItem, ...] = dataclass_field(repr=False)
    next: str | None = dataclass_field(repr=False)


@dataclass(frozen=True, slots=True)
class DocumentResynchronization:
    reference: DocumentReference
    floor: int
    replica: int
    previous_counter: int
    clock: int


class DocumentPhase(Enum):
    PROGRESS = 'progress'
    ACCEPTED = 'accepted'
    DUPLICATE = 'duplicate'
    CHECKPOINT_COMPLETE = 'checkpoint_complete'


@dataclass(frozen=True, slots=True)
class DocumentProgress:
    """A private turn result until the enclosing runner reports Committed."""
    phase: DocumentPhase
    revision: int | None


class DocumentOwner:
    def __init__(self, turn: Turn, document: int) -> None:
        self._turn, self.document = turn, _uint(document, 'Document ID', 1)
    def _apply(self, action: object) -> dict[str, Any]:
        self._turn._check()
        if not self._turn._native.caps.get('document_owner'): raise UnsupportedCapability('Native Station lacks Document owner operations')
        result: dict[str, Any] = self._turn._apply({'document': action})['document']
        return result
    def create(self, *, type_revision: int = 1, record_bytes: int = 4096, staging_bytes: int = 8192, staging_records: int = 2) -> None:
        self._apply({'create': {'document': str(self.document), 'type_revision': integer(type_revision, 'type revision', maximum=(1 << 32)-1),
            'record_bytes': integer(record_bytes, 'record bytes', maximum=(1 << 32)-1), 'staging_bytes': str(_uint(staging_bytes, 'staging bytes', 1)),
            'staging_records': integer(staging_records, 'staging records', maximum=(1 << 32)-1)}})
    def stage(self, job: int, change: PreparedDocumentChange, *, node_limit: int) -> DocumentProgress:
        if not isinstance(change, PreparedDocumentChange) or change.document != self.document: raise ValueError('Change belongs to another Document')
        v = self._apply({'stage': {'document': str(self.document), 'job': str(_uint(job, 'job', 1)), 'change': change.data.hex(),
                                 'node_limit': integer(node_limit, 'node limit', maximum=(1 << 32)-1)}})['progress']
        return DocumentProgress(DocumentPhase(v['phase']), None if v['revision'] is None else int(v['revision']))
    def checkpoint(self, job: int) -> DocumentProgress:
        v = self._apply({'checkpoint': {'document': str(self.document), 'job': str(_uint(job, 'job', 1))}})['progress']
        return DocumentProgress(DocumentPhase(v['phase']), None if v['revision'] is None else int(v['revision']))
    def merge_window(self, revisions: int) -> None:
        self._apply({'merge_window': {'document': str(self.document), 'revisions': str(_uint(revisions, 'merge window'))}})
    def reject(self, job: int, *, checkpoint: bool = False) -> None:
        if type(checkpoint) is not bool: raise TypeError('Expected checkpoint flag')
        self._apply({'reject': {'document': str(self.document), 'job': str(_uint(job, 'job', 1)), 'checkpoint': checkpoint}})
    def collect(self, job: int, *, checkpoint: bool = False, retired: bool = False) -> bool:
        if type(checkpoint) is not bool or type(retired) is not bool: raise TypeError('Expected collection flags')
        result: bool = self._apply({'collect': {'document': str(self.document), 'job': str(_uint(job, 'job', 1)), 'checkpoint': checkpoint, 'retired': retired}})['collected']
        return result
    def retire(self) -> None: self._apply({'retire': str(self.document)})


class _Reads:
    def __init__(self, realm: int, native_directory: Path | None) -> None:
        self.realm, self.native_directory = realm, native_directory
    def identity(self, resource: ResourceRef, document: int) -> object:
        if not isinstance(resource, ResourceRef) or resource.realm != self.realm: raise ValueError('Document belongs to another realm')
        return {'resource': resource.resource, 'document': str(_uint(document, 'Document ID', 1))}
    def reference(self, reference: DocumentReference) -> str:
        if not isinstance(reference, DocumentReference) or reference.resource.realm != self.realm: raise ValueError('Document belongs to another realm')
        return reference.encode(native_directory=self.native_directory).hex()
    def decode_reference(self, data: str) -> DocumentReference:
        return DocumentReference.decode(self.realm, bytes.fromhex(data), native_directory=self.native_directory)
    def description(self, v: dict[str, Any]) -> DocumentDescription:
        return DocumentDescription(self.decode_reference(v['reference']), v['source_revision'], int(v['floor']), int(v['merge_window']), v['retired'], int(v['active_job']), v['change_format'])
    def path_action(self, reference: DocumentReference, names: tuple[str, ...]) -> object:
        if not isinstance(names, tuple) or not 1 <= len(names) <= 16 or not all(isinstance(n, str) for n in names): raise TypeError('Expected a bounded immutable path')
        return {'path': {'reference': self.reference(reference), 'names': names}}
    def path(self, ref: DocumentReference, v: dict[str, Any]) -> DocumentPath:
        if self.decode_reference(v['reference']) != ref: raise IncompatibleNative('Document revision changed')
        return DocumentPath(ref, v['source_revision'], _register(v['value']))
    def sequence_action(self, reference: DocumentReference, object: DocumentDot, cursor: str | None) -> object:
        if cursor is not None and (not isinstance(cursor, str) or len(cursor.encode()) > 1024): raise ValueError('Invalid Document cursor')
        return {'sequence': {'reference': self.reference(reference), 'object': object._wire(), 'cursor': cursor}}
    def page(self, ref: DocumentReference, v: dict[str, Any]) -> DocumentPage:
        if self.decode_reference(v['reference']) != ref or len(v['items']) > 8: raise IncompatibleNative('Invalid Document page')
        return DocumentPage(ref, v['source_revision'], tuple(DocumentItem(_dot(item['id']), _register(item['values'])) for item in v['items']), v['next'])
    def sync(self, v: dict[str, Any]) -> DocumentResynchronization:
        return DocumentResynchronization(self.decode_reference(v['reference']), int(v['floor']), int(v['replica']), int(v['previous_counter']), int(v['clock']))


class DocumentReader:
    """One owned bounded result per call; no hidden whole-document accumulation."""
    def __init__(self, call: Callable[[object], dict[str, Any]], realm: int, native_directory: Path | None) -> None:
        self._call, self._values = call, _Reads(realm, native_directory)
    def describe(self, resource: ResourceRef, document: int) -> DocumentDescription:
        return self._values.description(self._call({'describe': self._values.identity(resource, document)})['description'])
    def path(self, reference: DocumentReference, names: tuple[str, ...]) -> DocumentPath:
        return self._values.path(reference, self._call(self._values.path_action(reference, names))['field'])
    def sequence(self, reference: DocumentReference, object: DocumentDot, cursor: str | None = None) -> DocumentPage:
        return self._values.page(reference, self._call(self._values.sequence_action(reference, object, cursor))['page'])
    def resynchronize(self, resource: ResourceRef, document: int, replica: int) -> DocumentResynchronization:
        return self._values.sync(self._call({'resynchronize': {'identity': self._values.identity(resource, document), 'replica': str(_uint(replica, 'replica', 1))}})['resynchronization'])
    def accepted_change(self, reference: DocumentReference) -> DocumentChange:
        return _change(self._call({'accepted_change': self._values.reference(reference)})['change'])


class AsyncDocumentReader:
    """Cancellation stops waiting; runner close joins the bounded native read."""
    def __init__(self, call: Callable[[object], Awaitable[dict[str, Any]]], realm: int, native_directory: Path | None) -> None:
        self._call, self._values = call, _Reads(realm, native_directory)
    async def describe(self, resource: ResourceRef, document: int) -> DocumentDescription:
        return self._values.description((await self._call({'describe': self._values.identity(resource, document)}))['description'])
    async def path(self, reference: DocumentReference, names: tuple[str, ...]) -> DocumentPath:
        return self._values.path(reference, (await self._call(self._values.path_action(reference, names)))['field'])
    async def sequence(self, reference: DocumentReference, object: DocumentDot, cursor: str | None = None) -> DocumentPage:
        return self._values.page(reference, (await self._call(self._values.sequence_action(reference, object, cursor)))['page'])
    async def resynchronize(self, resource: ResourceRef, document: int, replica: int) -> DocumentResynchronization:
        return self._values.sync((await self._call({'resynchronize': {'identity': self._values.identity(resource, document), 'replica': str(_uint(replica, 'replica', 1))}}))['resynchronization'])
    async def accepted_change(self, reference: DocumentReference) -> DocumentChange:
        return _change((await self._call({'accepted_change': self._values.reference(reference)}))['change'])
