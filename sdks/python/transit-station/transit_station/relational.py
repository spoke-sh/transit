"""Owned interactive Table relations; shared Zig code owns query semantics."""
from __future__ import annotations
import ctypes as c
from dataclasses import dataclass
import json
from pathlib import Path
import secrets
from types import TracebackType
from typing import Any, Callable, Literal, TypeVar
from transit_client._native import Library, encode, seed
from transit_client._worker import Worker, owned_await
from transit_client.errors import IncompatibleNative, UnsupportedCapability, native_error
from transit_client.types import integer
from .catalog_values import Connection, Basis, Snapshot, Position, ObjectIdentity
from . import catalog_values as v
from .table import RowIdentity
from .logical_values import ScalarType

T = TypeVar('T')


def fresh_id() -> str:
    """Retain with the statement until open succeeds; retries reuse the ID."""
    value = bytearray(secrets.token_bytes(16))
    value[0] |= 1
    return value.hex()


def _id(value: object) -> str:
    result = v._hex(value, 16, True)
    if not any(result): raise ValueError('Query ID must be nonzero')
    return result.hex()


@dataclass(frozen=True, slots=True)
class Options:
    consistency: Literal['independent_table_snapshots']
    resident_bytes: int
    spill_bytes: int
    result_bytes: int
    output_rows: int
    work_steps: int
    source_pins: int
    requests: int
    spill_work: int
    spill_directory: Path

    def _wire(self) -> dict[str, object]:
        if self.consistency != 'independent_table_snapshots': raise ValueError('Select independent_table_snapshots explicitly')
        result: dict[str, object] = {name: str(v._wide(getattr(self, name), name)) for name in
            ('resident_bytes', 'result_bytes', 'output_rows', 'work_steps', 'requests', 'spill_work')}
        result.update(consistency=self.consistency, spill_bytes=str(v._wide(self.spill_bytes, 'spill bytes', 0)),
            source_pins=integer(self.source_pins, 'source pins', maximum=2))
        return result


@dataclass(frozen=True, slots=True)
class Statement:
    sql: str
    routes: tuple[int, ...]
    namespace: int = 1

    def __post_init__(self) -> None:
        v._text(self.sql, 4096); integer(self.namespace, 'namespace')
        object.__setattr__(self, 'routes', tuple(self.routes))
        if not 1 <= len(self.routes) <= 2: raise ValueError('Select one or two explicit catalog routes')
        for route in self.routes: integer(route, 'route', minimum=0, maximum=1)

    def _wire(self) -> dict[str, object]: return dict(sql=self.sql, routes=self.routes, namespace=self.namespace)


@dataclass(frozen=True, slots=True)
class Reference:
    """A reference to one live host; saving it does not make the query durable."""
    definition: str
    id: str
    plan: str
    basis: str

    def __post_init__(self) -> None:
        v._definition(self.definition)
        _id(self.id)
        v._digest(self.plan)
        v._digest(self.basis)

    def _wire(self) -> dict[str, str]: return dict(definition=self.definition, id=self.id, plan=self.plan, basis=self.basis)
    def save(self) -> str: return json.dumps(self._wire(), separators=(',', ':'))

    @classmethod
    def restore(cls, saved: str) -> Reference:
        return _decode(_reference, json.loads(v._text(saved, 1024)))


def _reference(value: object) -> Reference:
    fields = v._object(value, 'definition id plan basis')
    return Reference(**fields)


@dataclass(frozen=True, slots=True)
class Column:
    name: str
    type: ScalarType
    nullable: bool


@dataclass(frozen=True, slots=True)
class Source:
    alias: str
    basis: Basis
    position: Position


@dataclass(frozen=True, slots=True)
class RetainedSource:
    basis: Basis
    snapshot: Snapshot
    def __post_init__(self) -> None:
        if not isinstance(self.basis, Basis) or not isinstance(self.snapshot, Snapshot): raise TypeError('Supply saved binding and snapshot')
        if (self.snapshot.owner.object != self.basis.interpretation.interpretation.object or
            self.snapshot.owner._wire()['connection'] != self.basis._wire()['connection']): raise ValueError('Foreign retained source')


@dataclass(frozen=True, slots=True)
class Description:
    plan: str
    sources: tuple[Source, ...]
    columns: tuple[Column, ...]
    join: Literal['inner', 'left'] | None
    grouped: bool
    executed: Literal[False] = False


def _array(value: object, minimum: int, maximum: int) -> list[Any]:
    if not isinstance(value, list) or not minimum <= len(value) <= maximum: raise ValueError('Invalid relational array bound')
    return value


def _description(value: object) -> Description:
    value = v._object(value, 'definition plan sources columns join grouped executed')
    v._definition(value['definition'])
    if v._boolean(value['executed']): raise ValueError('Expected a proposed plan')
    sources = []
    for item in _array(value['sources'], 1, 2):
        item = v._object(item, 'alias binding position')
        sources.append(Source(v._text(item['alias'], 255), Basis.restore(encode(item['binding']).decode()), v._position(item['position'])))
    columns = []
    for item in _array(value['columns'], 1, 128):
        item = v._object(item, 'name type nullable optional')
        kind, payload = v._variant(item['type'])
        if kind not in ('int64', 'uint64', 'utf8') or payload != {} or v._boolean(item['optional']):
            raise ValueError('Unsupported relational output type')
        columns.append(Column(v._text(item['name'], 255), ScalarType(kind), v._boolean(item['nullable'])))
    join = value['join']
    if join not in (None, 'inner', 'left'): raise ValueError('Invalid relational join')
    return Description(v._digest(value['plan']), tuple(sources), tuple(columns), join, v._boolean(value['grouped']))


@dataclass(frozen=True, slots=True)
class Cut:
    object: ObjectIdentity
    position: Position
    commitment: str
    schema: str


@dataclass(frozen=True, slots=True)
class Opened:
    reference: Reference
    description: Description
    cuts: tuple[Cut, ...]
    complete_coverage: Literal[False] = False


def _opened(value: object, identity: str, sources: tuple[RetainedSource, ...]) -> Opened:
    value = v._object(value, 'reference description cuts complete_coverage')
    reference, description = _reference(value['reference']), _description(value['description'])
    if (reference.id != identity or reference.plan != description.plan or v._boolean(value['complete_coverage']) or
        len(sources) != len(description.sources)): raise ValueError('Relational open changed its requested identity')
    cuts: list[Cut] = []
    for item in _array(value['cuts'], len(sources), len(sources)):
        item = v._object(item, 'object position commitment schema')
        cut = Cut(v._object_identity(item['object']), v._position(item['position']), v._digest(item['commitment']), v._digest(item['schema']))
        source = description.sources[len(cuts)]
        original = sources[len(cuts)]
        if (source.basis._wire() != original.basis._wire() or cut.object != source.basis.interpretation.interpretation.object or
            cut.schema != source.basis.interpretation.schema_fingerprint or cut.position != source.position): raise ValueError('Cut differs from its original source')
        cuts.append(cut)
    return Opened(reference, description, tuple(cuts))


@dataclass(frozen=True, slots=True)
class PairIdentity:
    left: RowIdentity
    right: RowIdentity | None


@dataclass(frozen=True, slots=True)
class GroupIdentity:
    keys: tuple[int | str | None, ...]


@dataclass(frozen=True, slots=True)
class Row:
    identity: PairIdentity | GroupIdentity
    cells: tuple[int | str | None, ...]


def _signed(value: object) -> int:
    if not isinstance(value, str) or not 1 <= len(value) <= 20: raise ValueError('Invalid int64')
    result = int(value)
    if str(result) != value or not -(1 << 63) <= result < (1 << 63): raise ValueError('Invalid canonical int64')
    return result


def _text_scalar(value: object) -> str:
    if not isinstance(value, str) or len(value.encode('utf8')) > 1024 * 1024: raise ValueError('Invalid relational text')
    return value


def _group_scalar(value: object) -> int | str:
    kind, payload = v._variant(value)
    if kind == 'signed': return _signed(payload)
    if kind == 'utf8': return _text_scalar(payload)
    raise ValueError('Invalid relational group key')


def _row(value: object) -> Row:
    value = v._object(value, 'identity cells')
    kind, payload = v._variant(value['identity'])
    identity: PairIdentity | GroupIdentity
    if kind == 'pair':
        payload = v._object(payload, 'left right')
        identity = PairIdentity(RowIdentity(v._hex(payload['left'], 20, True)),
            None if payload['right'] is None else RowIdentity(v._hex(payload['right'], 20, True)))
    elif kind == 'group': identity = GroupIdentity(tuple(None if k is None else _group_scalar(k) for k in _array(payload, 0, 128)))
    else: raise ValueError('Unknown relational identity')
    cells: list[int | str | None] = []
    for item in _array(value['cells'], 1, 128):
        tag, cell = v._variant(item)
        if tag == 'null':
            v._object(cell, '')
            cells.append(None)
        elif tag == 'value':
            atom = v._object(cell, 'atom')['atom']
            scalar, data = v._variant(atom)
            if scalar == 'signed': cells.append(_signed(data))
            elif scalar == 'unsigned': cells.append(v._decimal(data, 0))
            elif scalar == 'utf8': cells.append(_text_scalar(data))
            else: raise ValueError('Unsupported relational scalar')
        else: raise ValueError('Unsupported relational cell')
    return Row(identity, tuple(cells))


@dataclass(frozen=True, slots=True)
class Page:
    reference: Reference
    ordinal: int
    row: Row | None
    complete_coverage: bool


def _page(value: object, reference: Reference, ordinal: int) -> Page:
    value = v._object(value, 'reference ordinal row complete_coverage')
    received = _reference(value['reference'])
    complete = v._boolean(value['complete_coverage'])
    if received != reference or v._decimal(value['ordinal'], 0) != ordinal or complete != (value['row'] is None):
        raise ValueError('Relational page changed its identity or coverage')
    return Page(received, ordinal, None if complete else _row(value['row']), complete)


def _decode(parser: Callable[..., T], *args: object) -> T:
    try: return parser(*args)
    except (ValueError, TypeError, KeyError, OverflowError) as error:
        raise IncompatibleNative('Invalid relational response') from error


def _closed(value: object) -> None: v._object(value, '')


class Client:
    """One active query and one owned native worker; close joins in-flight work."""
    def __init__(self, url: str, principal: int, seed_file: Path, catalogs: tuple[Connection, ...], options: Options, *,
                 timeout_ms: int = 5000, native_directory: Path | None = None, service_url: str | None = None) -> None:
        catalogs = tuple(catalogs)
        if not 1 <= len(catalogs) <= 2 or not all(isinstance(item, Connection) for item in catalogs):
            raise ValueError('Select one or two catalog connections')
        if any(item != catalogs[0] for item in catalogs): raise ValueError('Select one direct catalog connection')
        self._catalogs = catalogs
        self._principal = integer(principal, 'principal', minimum=0)
        config = encode(dict(timeout_ms=integer(timeout_ms, 'timeout', maximum=60000), relational=dict(
            definition=v.DEFINITION, catalogs=[item._wire(principal) for item in catalogs], options=options._wire(),
            service_url=None if service_url is None else v._text(service_url, 2048),
            spill_directory=v._text(str(options.spill_directory), 4096))))
        endpoint = v._text(url, 2048).encode()
        self._api = Library('station', Path(__file__).with_name('station-abi.json'), native_directory)
        self._worker = Worker(self._api.contract['minimum_stack_bytes'])
        self._handle = c.c_void_p()
        def create() -> None:
            key = seed(seed_file)
            try:
                status = self._api.lib.station_unified_query_create(1, endpoint, len(endpoint), key, config, len(config), c.byref(self._handle))
                if status: raise native_error(status, phase='open_relational')
            finally: c.memset(key, 0, 32)
        try:
            self._worker.call(create)
            caps = v._object(self._call({'capabilities': {}}, 'capabilities'), 'definition sources active_queries page_rows interactive captured maintained consistency')
            v._definition(caps['definition'])
            if caps['interactive'] is not True or caps['page_rows'] != 1 or caps['active_queries'] != 1 or caps['consistency'] != 'independent_table_snapshots':
                raise UnsupportedCapability('Native caller lacks interactive relational capabilities')
        except BaseException:
            self.close()
            raise

    def _invoke(self, action: object, expected: str) -> object:
        data = encode({'relational': action})
        result = self._api.call('station_unified_query_call', self._handle, data, len(data))
        outer = _decode(v._object, result, 'relational')
        return _decode(v._object, outer['relational'], expected)[expected]

    def _call(self, action: object, expected: str) -> object:
        return self._worker.call(lambda: self._invoke(action, expected))

    def _description(self, value: object, statement: Statement) -> Description:
        result = _description(value)
        if len(result.sources) != len(statement.routes): raise ValueError('Changed source count')
        for source, route in zip(result.sources, statement.routes):
            if (route >= len(self._catalogs) or source.basis.connection != self._catalogs[route] or
                source.basis.principal != self._principal or source.basis.namespace != statement.namespace): raise ValueError('Changed source connection')
        return result

    def _open(self, identity: str, statement: Statement, sources: tuple[RetainedSource, ...]) -> object:
        if len(sources) != len(statement.routes): raise ValueError('Supply one saved binding and explicit snapshot per source')
        for source, route in zip(sources, statement.routes):
            if (route >= len(self._catalogs) or source.basis.connection != self._catalogs[route] or
                source.basis.principal != self._principal or source.basis.namespace != statement.namespace): raise ValueError('Foreign retained source')
        return {'open': dict(id=_id(identity), statement=statement._wire(), bindings=[source.basis._wire() for source in sources],
                             snapshots=[source.snapshot._wire() for source in sources])}

    def explain(self, statement: Statement) -> Description:
        return _decode(self._description, self._call({'explain': statement._wire()}, 'explained'), statement)

    def open_query(self, identity: str, statement: Statement, sources: tuple[RetainedSource, ...]) -> Opened:
        sources = tuple(sources)
        return _decode(_opened, self._call(self._open(identity, statement, sources), 'opened'), identity, sources)

    def page(self, reference: Reference, ordinal: int) -> Page:
        value = self._call({'page': {'reference': reference._wire(), 'ordinal': str(v._wide(ordinal, 'ordinal', 0))}}, 'page')
        return _decode(_page, value, reference, ordinal)

    def close_query(self, reference: Reference) -> None:
        _decode(_closed, self._call({'close': reference._wire()}, 'closed'))

    def _destroy(self) -> None:
        self._api.lib.station_unified_query_destroy(self._handle)
        self._handle = c.c_void_p()

    def close(self) -> None: self._worker.close(self._destroy)
    def __enter__(self) -> Client: return self
    def __exit__(self, kind: type[BaseException] | None, value: BaseException | None, traceback: TracebackType | None) -> None: self.close()


class AsyncClient:
    """Cancelling an await leaves its native operation owned; close joins it."""
    def __init__(self, url: str, principal: int, seed_file: Path, catalogs: tuple[Connection, ...], options: Options, *,
                 timeout_ms: int = 5000, native_directory: Path | None = None, service_url: str | None = None) -> None:
        self._owner = Client(url, principal, seed_file, catalogs, options, timeout_ms=timeout_ms, native_directory=native_directory, service_url=service_url)

    async def _call(self, action: object, expected: str) -> object:
        return await owned_await(self._owner._worker.submit(lambda: self._owner._invoke(action, expected)))

    async def explain(self, statement: Statement) -> Description:
        return _decode(self._owner._description, await self._call({'explain': statement._wire()}, 'explained'), statement)

    async def open_query(self, identity: str, statement: Statement, sources: tuple[RetainedSource, ...]) -> Opened:
        sources = tuple(sources)
        return _decode(_opened, await self._call(self._owner._open(identity, statement, sources), 'opened'), identity, sources)

    async def page(self, reference: Reference, ordinal: int) -> Page:
        value = await self._call({'page': {'reference': reference._wire(), 'ordinal': str(v._wide(ordinal, 'ordinal', 0))}}, 'page')
        return _decode(_page, value, reference, ordinal)

    async def close_query(self, reference: Reference) -> None:
        _decode(_closed, await self._call({'close': reference._wire()}, 'closed'))

    async def close(self) -> None: await self._owner._worker.aclose(self._owner._destroy)
    async def __aenter__(self) -> AsyncClient: return self
    async def __aexit__(self, kind: type[BaseException] | None, value: BaseException | None, traceback: TracebackType | None) -> None: await self.close()
