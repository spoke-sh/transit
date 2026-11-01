"""Owned general Table values; storage semantics belong to the shared Zig owner."""
from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum
import copy
import json
import math
from pathlib import Path
from typing import Any, Generic, Literal, TypeAlias, TypeVar, cast
from transit_client import ResourceRef
from transit_client._native import encode
from transit_client.types import integer, owned_bytes
from . import logical_values as logical

# Read the generated definition and bounds; never default saved artifacts to them.
_contract = json.loads(Path(__file__).with_name('station-abi.json').read_bytes())
DEFINITION: str = _contract['definition']
LIMITS: dict[str, int] = _contract['limits']
del _contract
E = TypeVar('E', bound=Enum)
W = TypeVar('W')


class _WireBudget:
    """Charge a fragment before converting the next owned logical value."""
    def __init__(self, limit: int): self.remaining = limit
    def take(self, value: W) -> W:
        self.remaining -= len(encode(value))
        if self.remaining < 0: raise ValueError('Table wire budget exceeded')
        return value


def _wide(value: object, name: str = 'identity', minimum: int = 1) -> int:
    return integer(value, name, minimum=minimum, maximum=(1 << 64) - 1)


def _text(value: object, limit: int) -> str:
    if not isinstance(value, str) or not value: raise ValueError('Expected nonempty text')
    owned_bytes(value.encode(), limit)
    return value


def _name(value: object) -> str:
    result = _text(value, 255)
    if '\0' in result: raise ValueError('NUL in catalog name')
    return result


def _boolean(value: object) -> bool:
    if type(value) is not bool: raise ValueError('Expected boolean')
    return value


def _definition(value: object) -> str:
    if value != DEFINITION: raise ValueError('Foreign or missing catalog definition')
    return DEFINITION


def _hex(value: object, limit: int, exact: bool = False) -> bytes:
    text = _text(value, limit * 2)
    result = owned_bytes(bytes.fromhex(text), limit)
    if result.hex() != text or (exact and len(result) != limit): raise ValueError('Expected canonical hexadecimal bytes')
    return result


def _digest(value: object) -> str: return _hex(value, 32, True).hex()


def _object(value: object, fields: str) -> dict[str, Any]:
    if not isinstance(value, dict) or set(value) != set(fields.split()): raise ValueError('Unexpected catalog response fields')
    return value


def _variant(value: object) -> tuple[str, Any]:
    if not isinstance(value, dict) or len(value) != 1: raise ValueError('Expected one catalog variant')
    kind, payload = next(iter(value.items()))
    if not isinstance(kind, str): raise ValueError('Expected variant tag')
    return kind, payload


def _decimal(value: object, minimum: int = 1) -> int:
    if not isinstance(value, str) or not 1 <= len(value) <= 20 or not value.isascii() or not value.isdigit(): raise ValueError('Expected canonical decimal string')
    result = _wide(int(value), minimum=minimum)
    if str(result) != value: raise ValueError('Expected canonical decimal string')
    return result


@dataclass(frozen=True, slots=True)
class Scope:
    resource: ResourceRef
    catalog: int
    def __post_init__(self) -> None:
        if not isinstance(self.resource, ResourceRef): raise TypeError('Expected resource reference')
        _wide(self.catalog)
    def _wire(self) -> dict[str, object]:
        return dict(realm=self.resource.realm, resource=self.resource.resource, catalog=str(self.catalog))


@dataclass(frozen=True, slots=True)
class TableLimits:
    record_bytes: int
    staging_bytes: int
    staging_records: int
    def __post_init__(self) -> None:
        integer(self.record_bytes, 'record bytes', maximum=0xffffffff)
        _wide(self.staging_bytes, 'staging bytes')
        integer(self.staging_records, 'staging records', maximum=0xffffffff)
        if self.staging_bytes < self.record_bytes: raise ValueError('Staging quota cannot be smaller than one record')
    def _wire(self) -> object:
        return dict(record_bytes=self.record_bytes, staging_bytes=str(self.staging_bytes), staging_records=self.staging_records)


@dataclass(frozen=True, slots=True)
class AuthorityProfile:
    database_domain: int
    schema_domain: int
    table_domain: int
    stream_domain: int
    queue_domain: int
    kv_domain: int
    database: int
    initial_schema: int
    initial_schema_authority: int
    def __post_init__(self) -> None:
        for name, value in self._wire().items(): integer(value, name)
        if len({self.database_domain, self.schema_domain, self.table_domain, self.stream_domain, self.queue_domain, self.kv_domain}) != 6 or self.database == self.initial_schema_authority:
            raise ValueError('Distinct native authorization bindings are required')
    def _wire(self) -> dict[str, int]:
        return {name: getattr(self, name) for name in ('database_domain', 'schema_domain', 'table_domain', 'stream_domain', 'queue_domain', 'kv_domain', 'database', 'initial_schema', 'initial_schema_authority')}


@dataclass(frozen=True, slots=True)
class Subject:
    principal: int
    login_role: int
    role: int
    credential_epoch: int
    audience: int
    context: bytes
    def __post_init__(self) -> None:
        integer(self.principal, 'principal', minimum=0)
        integer(self.login_role, 'login role', minimum=0)
        integer(self.role, 'role', minimum=0)
        integer(self.credential_epoch, 'credential epoch')
        integer(self.audience, 'audience')
        object.__setattr__(self, 'context', owned_bytes(self.context, 32))
        if len(self.context) != 32: raise ValueError('Expected subject context digest')


class Encoding(str, Enum):
    PLAIN = 'plain'
    BITPACKED = 'bitpacked'
    RLE = 'rle'
    DICTIONARY = 'dictionary'
    FSST = 'fsst'
    COMP = 'comp'
    COMP_3 = 'comp_3'
    ZONED = 'zoned'
    IBM_HFP = 'ibm_hfp'
    EBCDIC = 'ebcdic'


class Collation(str, Enum):
    NONE = 'none'
    UTF8_BINARY = 'utf8_binary'
    ASCII_CI = 'ascii_ci'
    EBCDIC_CP037 = 'ebcdic_cp037'
    ICU_ROOT = 'icu_root'
    EBCDIC_037_PAD = 'ebcdic_037_pad'
    EBCDIC_1047_NOPAD = 'ebcdic_1047_nopad'


@dataclass(frozen=True, slots=True)
class TimezoneRules:
    version: str
    digest: bytes
    zone: str
    tzif: bytes
    def __post_init__(self) -> None:
        object.__setattr__(self, 'digest', owned_bytes(self.digest, 32))
        object.__setattr__(self, 'tzif', owned_bytes(self.tzif, 128 * 1024))
        if len(self.digest) != 32: raise ValueError('Expected complete timezone digest')


@dataclass(frozen=True, slots=True)
class SpatialSemantics:
    srid: int
    vertical_datum: int
    unit_scale_nm: int
    axis_orientation: Literal['right_handed_z_up', 'right_handed_y_up']
    manifold: Literal['planar', 'geodesic_wgs84']
    snap_grid_scale: float
    exact_predicates: Literal['shewchuk_adaptive']
    curve_order: Literal['none', 's2_hilbert', 'h3', 'hilbert_3d']
    def __post_init__(self) -> None:
        if self.axis_orientation not in ('right_handed_z_up', 'right_handed_y_up'): raise ValueError('Unknown spatial axis orientation')
        if self.manifold not in ('planar', 'geodesic_wgs84'): raise ValueError('Unknown spatial manifold')
        if self.exact_predicates != 'shewchuk_adaptive': raise ValueError('Unknown spatial predicate mode')
        if self.curve_order not in ('none', 's2_hilbert', 'h3', 'hilbert_3d'): raise ValueError('Unknown spatial curve order')
        if isinstance(self.snap_grid_scale, bool) or not isinstance(self.snap_grid_scale, (int, float)) or not math.isfinite(self.snap_grid_scale) or self.snap_grid_scale <= 0:
            raise ValueError('Invalid spatial grid scale')


@dataclass(frozen=True, slots=True)
class ColumnSemantics:
    rounding: Literal['reject', 'half_even', 'toward_zero'] | None = None
    metric: Literal['l2_squared', 'cosine', 'dot_product', 'hamming'] | None = None
    timezone: TimezoneRules | None = None
    spatial: SpatialSemantics | None = None
    def _wire(self) -> dict[str, Any]:
        zone, spatial = self.timezone, self.spatial
        if self.rounding not in (None, 'reject', 'half_even', 'toward_zero'): raise ValueError('Unknown numeric rounding')
        if self.metric not in (None, 'l2_squared', 'cosine', 'dot_product', 'hamming'): raise ValueError('Unknown vector metric')
        return dict(rounding=self.rounding, metric=self.metric,
            timezone=None if zone is None else dict(version=dict(version_id=_text(zone.version, 64), digest=list(zone.digest)), zone=_name(zone.zone), tzif_hex=zone.tzif.hex()),
            spatial=None if spatial is None else dict(srid=integer(spatial.srid, 'SRID', minimum=1, maximum=0xffffffff),
                vertical_datum=integer(spatial.vertical_datum, 'vertical datum', minimum=0, maximum=0xffff), unit_scale_nm=str(_wide(spatial.unit_scale_nm)),
                axis_orientation=spatial.axis_orientation, manifold=spatial.manifold, snap_grid_scale=spatial.snap_grid_scale,
                exact_predicates=spatial.exact_predicates, curve_order=spatial.curve_order))


def _semantics(value: object) -> ColumnSemantics:
    v = _object(value, 'rounding metric timezone spatial')
    zone, spatial = None, None
    if v['timezone'] is not None:
        z = _object(v['timezone'], 'version zone tzif_hex')
        version = _object(z['version'], 'version_id digest')
        digest = version['digest']
        if not isinstance(digest, list) or len(digest) != 32: raise ValueError('Invalid timezone digest')
        zone = TimezoneRules(_text(version['version_id'], 64), bytes(integer(n, 'digest byte', minimum=0, maximum=255) for n in digest), _name(z['zone']), _hex(z['tzif_hex'], 128 * 1024))
    if v['spatial'] is not None:
        s = _object(v['spatial'], 'srid vertical_datum unit_scale_nm axis_orientation manifold snap_grid_scale exact_predicates curve_order')
        spatial = SpatialSemantics(s['srid'], s['vertical_datum'], _decimal(s['unit_scale_nm']), s['axis_orientation'], s['manifold'], s['snap_grid_scale'], s['exact_predicates'], s['curve_order'])
    result = ColumnSemantics(v['rounding'], v['metric'], zone, spatial)
    result._wire()
    return result


@dataclass(frozen=True, slots=True)
class Column:
    id: int
    name: str
    type: logical.Descriptor
    nullable: bool = True
    default: logical.Cell | None = None
    max_characters: int | None = None
    encoding: Encoding = Encoding.PLAIN
    collation: Collation = Collation.NONE
    semantics: ColumnSemantics = ColumnSemantics()
    def _wire(self) -> dict[str, Any]:
        return dict(id=str(_wide(self.id)), **_column(self.name, self.type, self.nullable, self.default, self.max_characters, self.encoding, self.collation, self.semantics))


def _column(name: str, datatype: logical.Descriptor, nullable: bool, default: logical.Cell | None, max_characters: int | None, encoding: Encoding, collation: Collation, semantics: ColumnSemantics = ColumnSemantics()) -> dict[str, Any]:
    return dict(name=_name(name), type=logical.type_wire(datatype), nullable=_boolean(nullable), default=None if default is None else logical.cell_wire(default),
                max_characters=None if max_characters is None else integer(max_characters, 'characters', maximum=0xffffffff), encoding=_enum(encoding, Encoding), collation=_enum(collation, Collation), semantics=semantics._wire())


CheckComparison: TypeAlias = Literal['lt', 'lte', 'eq', 'gte', 'gt', 'neq']

@dataclass(frozen=True, slots=True)
class CheckLiteral:
    column: int
    op: CheckComparison
    literal: logical.Atom

@dataclass(frozen=True, slots=True)
class CheckColumns:
    left: int
    op: CheckComparison
    right: int

@dataclass(frozen=True, slots=True)
class CheckNull:
    column: int
    negate: bool = False

CheckAtom: TypeAlias = CheckLiteral | CheckColumns | CheckNull

@dataclass(frozen=True, slots=True)
class CheckConstraint:
    id: int
    name: str
    atoms: tuple[CheckAtom, ...]
    validated: bool = True
    def __post_init__(self) -> None: object.__setattr__(self, 'atoms', tuple(self.atoms))

ReferentialAction: TypeAlias = Literal['restrict', 'no_action', 'cascade', 'set_null']

@dataclass(frozen=True, slots=True)
class ForeignKeyConstraint:
    id: int
    name: str
    local_columns: tuple[int, ...]
    target_definition: Interpretation
    target_schema_revision: int
    target_columns: tuple[int, ...]
    on_delete: ReferentialAction = 'restrict'
    on_update: ReferentialAction = 'restrict'
    enforcement: Literal['staged_awaiting_index'] = 'staged_awaiting_index'
    def __post_init__(self) -> None:
        object.__setattr__(self, 'local_columns', tuple(self.local_columns))
        object.__setattr__(self, 'target_columns', tuple(self.target_columns))

@dataclass(frozen=True, slots=True)
class TableIntegrity:
    next_id: int = 1
    checks: tuple[CheckConstraint, ...] = ()
    foreign_keys: tuple[ForeignKeyConstraint, ...] = ()
    def __post_init__(self) -> None:
        object.__setattr__(self, 'checks', tuple(self.checks)); object.__setattr__(self, 'foreign_keys', tuple(self.foreign_keys))
    def _wire(self) -> dict[str, Any]:
        if len(self.checks) + len(self.foreign_keys) > 64: raise ValueError('Too many Table constraints')
        checks, foreign_keys = [], []
        for check in self.checks:
            if not isinstance(check, CheckConstraint) or not 1 <= len(check.atoms) <= 32: raise ValueError('Invalid CHECK constraint')
            atoms: list[dict[str, Any]] = []
            for atom in check.atoms:
                if isinstance(atom, CheckLiteral): atoms.append({'compare_literal': dict(column=str(_wide(atom.column)), op=_one_of(atom.op, ('lt', 'lte', 'eq', 'gte', 'gt', 'neq')), literal={'value': {'atom': logical.atom_wire(atom.literal)}})})
                elif isinstance(atom, CheckColumns): atoms.append({'compare_columns': dict(left_column=str(_wide(atom.left)), op=_one_of(atom.op, ('lt', 'lte', 'eq', 'gte', 'gt', 'neq')), right_column=str(_wide(atom.right)))})
                elif isinstance(atom, CheckNull): atoms.append({'is_not_null' if _boolean(atom.negate) else 'is_null': str(_wide(atom.column))})
                else: raise ValueError('Invalid CHECK atom')
            checks.append(dict(id=integer(check.id, 'constraint id', maximum=0xffffffff), name=_name(check.name), validated=_boolean(check.validated), atoms=atoms))
        for fk in self.foreign_keys:
            if not isinstance(fk, ForeignKeyConstraint) or not 1 <= len(fk.local_columns) <= 128 or len(fk.local_columns) != len(fk.target_columns): raise ValueError('Invalid foreign-key columns')
            d = fk.target_definition; o = d.object; s = o.scope
            definition = dict(realm=str(s.resource.realm), resource=str(s.resource.resource), catalog=str(_wide(s.catalog)), branch=str(_wide(o.branch)), object=str(_wide(o.object_id)), revision=str(_wide(d.revision)), digest=_digest(d.digest))
            foreign_keys.append(dict(id=integer(fk.id, 'constraint id', maximum=0xffffffff), name=_name(fk.name), local_columns=[str(_wide(c)) for c in fk.local_columns], target_object=definition['object'], target_revision=str(_wide(fk.target_schema_revision)), target_definition=definition, target_columns=[str(_wide(c)) for c in fk.target_columns], on_delete=_one_of(fk.on_delete, ('restrict', 'no_action', 'cascade', 'set_null')), on_update=_one_of(fk.on_update, ('restrict', 'no_action', 'cascade', 'set_null')), enforcement=_one_of(fk.enforcement, ('staged_awaiting_index',))))
        return dict(next_id=integer(self.next_id, 'constraint identity', maximum=0xffffffff), checks=checks, foreign_keys=foreign_keys)


def _integrity(value: object) -> TableIntegrity:
    if isinstance(value, dict): value = {'next_id': 1, 'checks': [], 'foreign_keys': [], **value}
    v = _object(value, 'next_id checks foreign_keys'); checks, keys = [], []
    if not isinstance(v['checks'], list) or not isinstance(v['foreign_keys'], list) or len(v['checks']) + len(v['foreign_keys']) > 64: raise ValueError('Invalid Table constraints')
    for raw in v['checks']:
        c = _object(raw, 'id name atoms validated')
        atoms: list[CheckLiteral | CheckColumns | CheckNull] = []
        if not isinstance(c['atoms'], list) or not 1 <= len(c['atoms']) <= 32: raise ValueError('Invalid CHECK atoms')
        for raw_atom in c['atoms']:
            tag, item = _variant(raw_atom)
            if tag == 'compare_literal':
                x = _object(item, 'column op literal'); cell = logical.cell_from_wire(x['literal'])
                if not isinstance(cell, logical.Present) or not isinstance(cell.value, logical.Atom): raise ValueError('Invalid CHECK literal')
                atoms.append(CheckLiteral(_decimal(x['column']), x['op'], cell.value))
            elif tag == 'compare_columns':
                x = _object(item, 'left_column op right_column'); atoms.append(CheckColumns(_decimal(x['left_column']), x['op'], _decimal(x['right_column'])))
            elif tag in ('is_null', 'is_not_null'): atoms.append(CheckNull(_decimal(item), tag == 'is_not_null'))
            else: raise ValueError('Invalid CHECK atom')
        checks.append(CheckConstraint(c['id'], _name(c['name']), tuple(atoms), _boolean(c['validated'])))
    for raw in v['foreign_keys']:
        fk = _object(raw, 'id name local_columns target_object target_revision target_definition target_columns on_delete on_update enforcement')
        d = _object(fk['target_definition'], 'realm resource catalog branch object revision digest')
        if d['object'] != fk['target_object']: raise ValueError('Foreign-key identity mismatch')
        definition = Interpretation(ObjectIdentity(Scope(ResourceRef(_decimal(d['realm']), _decimal(d['resource'])), _decimal(d['catalog'])), _decimal(d['branch']), _decimal(d['object'])), _decimal(d['revision']), _digest(d['digest']))
        keys.append(ForeignKeyConstraint(fk['id'], _name(fk['name']), tuple(_decimal(c) for c in fk['local_columns']), definition, _decimal(fk['target_revision']), tuple(_decimal(c) for c in fk['target_columns']), fk['on_delete'], fk['on_update'], fk['enforcement']))
    result = TableIntegrity(v['next_id'], tuple(checks), tuple(keys)); result._wire(); return result


@dataclass(frozen=True, slots=True)
class Schema:
    object_id: int
    revision: int
    next_column: int
    columns: tuple[Column, ...]
    primary_key: tuple[int, ...] = ()
    integrity: TableIntegrity = field(default_factory=TableIntegrity)
    def __post_init__(self) -> None:
        _wide(self.object_id); _wide(self.revision); _wide(self.next_column)
        object.__setattr__(self, 'columns', tuple(self.columns)); object.__setattr__(self, 'primary_key', tuple(self.primary_key))
        if not 1 <= len(self.columns) <= 128 or len(self.primary_key) > len(self.columns): raise ValueError('Invalid Table column count')
        owned_bytes(encode(self._wire()), 2 * 1024 * 1024)
    def _wire(self) -> object:
        budget = _WireBudget(2 * 1024 * 1024)
        return dict(definition=DEFINITION, object=str(self.object_id), revision=str(self.revision), next_column=str(self.next_column),
                    columns=[budget.take(item._wire()) for item in self.columns], primary_key=[str(_wide(item)) for item in self.primary_key], integrity=budget.take(self.integrity._wire()))




# Direct lifecycle values. Every saved binding preserves its original definition.

class Default(Enum):
    VALUE = 'default'


@dataclass(frozen=True, slots=True)
class Assignment:
    column: int
    value: logical.Cell | Default


class BooleanOperator(str, Enum):
    ALL = 'all'
    NEGATE = 'negate'
    CONJUNCTION = 'conjunction'
    DISJUNCTION = 'disjunction'


class CellState(str, Enum):
    MISSING = 'missing'
    NULL = 'null'
    TYPE_ERROR = 'type_error'
    VALUE = 'value'
    CONFLICT = 'conflict'


class CompareOperator(str, Enum):
    EQ = 'eq'
    NE = 'ne'
    LT = 'lt'
    LE = 'le'
    GT = 'gt'
    GE = 'ge'


@dataclass(frozen=True, slots=True)
class StatePredicate:
    column: int
    state: CellState


@dataclass(frozen=True, slots=True)
class Comparison:
    column: int
    op: CompareOperator
    value: logical.Atom


Predicate: TypeAlias = BooleanOperator | StatePredicate | Comparison


@dataclass(frozen=True, slots=True)
class Insert:
    rows: tuple[tuple[Assignment, ...], ...]
    def __post_init__(self) -> None: object.__setattr__(self, 'rows', tuple(tuple(row) for row in self.rows))


@dataclass(frozen=True, slots=True)
class Update:
    assignments: tuple[Assignment, ...]
    predicate: tuple[Predicate, ...] | None = None
    def __post_init__(self) -> None:
        object.__setattr__(self, 'assignments', tuple(self.assignments))
        if self.predicate is not None: object.__setattr__(self, 'predicate', tuple(self.predicate))


@dataclass(frozen=True, slots=True)
class Delete:
    predicate: tuple[Predicate, ...] | None = None
    def __post_init__(self) -> None:
        if self.predicate is not None: object.__setattr__(self, 'predicate', tuple(self.predicate))


Mutation: TypeAlias = Insert | Update | Delete


@dataclass(frozen=True, slots=True)
class AddColumn:
    name: str
    type: logical.Descriptor
    nullable: bool = True
    default: logical.Cell | None = None
    max_characters: int | None = None
    encoding: Encoding = Encoding.PLAIN
    collation: Collation = Collation.NONE
    semantics: ColumnSemantics = ColumnSemantics()


@dataclass(frozen=True, slots=True)
class DropColumn:
    column: int


@dataclass(frozen=True, slots=True)
class RenameColumn:
    column: int
    name: str


@dataclass(frozen=True, slots=True)
class SetDefault:
    column: int
    value: logical.Cell | None


@dataclass(frozen=True, slots=True)
class SetNullable:
    column: int
    nullable: bool


@dataclass(frozen=True, slots=True)
class SetType:
    column: int
    type: logical.Descriptor
    max_characters: int | None = None


@dataclass(frozen=True, slots=True)
class SetPhysical:
    column: int
    encoding: Encoding
    collation: Collation
    semantics: ColumnSemantics | None = None


@dataclass(frozen=True, slots=True)
class SetIntegrity:
    schema: Schema


Change: TypeAlias = AddColumn | DropColumn | RenameColumn | SetDefault | SetNullable | SetType | SetPhysical | SetIntegrity


@dataclass(frozen=True, slots=True)
class Create:
    schema: Schema
    if_not_exists: bool = False


@dataclass(frozen=True, slots=True)
class Alter:
    basis: Basis
    change: Change


@dataclass(frozen=True, slots=True)
class Rename:
    basis: Basis
    name: str


@dataclass(frozen=True, slots=True)
class Drop:
    basis: Basis | None = None
    if_exists: bool = False


@dataclass(frozen=True, slots=True)
class Mutate:
    basis: Basis
    mutation: Mutation
    ingestion: Literal['point', 'bulk'] = 'point'


Operation: TypeAlias = Create | Alter | Rename | Drop | Mutate


def _enum(value: E, kind: type[E]) -> str:
    if not isinstance(value, kind): raise TypeError('Expected typed catalog variant')
    result: str = value.value
    return result


def _scope(value: object) -> Scope:
    v = _object(value, 'realm resource catalog')
    return Scope(ResourceRef(v['realm'], v['resource']), _decimal(v['catalog']))


def _schema(value: object) -> Schema:
    v = _object(value, 'definition object revision next_column columns primary_key integrity')
    _definition(v['definition'])
    if not isinstance(v['columns'], list) or not 1 <= len(v['columns']) <= 128 or not isinstance(v['primary_key'], list): raise ValueError('Invalid columns')
    columns = []
    for item in v['columns']:
        c = _object(item, 'id name type nullable default max_characters encoding collation semantics')
        columns.append(Column(_decimal(c['id']), _name(c['name']), logical.type_from_wire(c['type']), _boolean(c['nullable']), None if c['default'] is None else logical.cell_from_wire(c['default']), c['max_characters'], Encoding(c['encoding']), Collation(c['collation']), _semantics(c['semantics'])))
    return Schema(_decimal(v['object']), _decimal(v['revision']), _decimal(v['next_column']), tuple(columns), tuple(_decimal(k) for k in v['primary_key']), _integrity(v['integrity']))


def _assignments(values: tuple[Assignment, ...], budget: _WireBudget) -> object:
    if len(values) > 128: raise ValueError('Too many Table assignments')
    return [budget.take(dict(column=str(_wide(item.column)), value={'default': {}} if item.value is Default.VALUE else {'cell': logical.cell_wire(item.value)})) for item in values]


def _predicate(value: Predicate) -> object:
    if isinstance(value, BooleanOperator): return {'atom': {'all': {}}} if value is BooleanOperator.ALL else {value.value: {}}
    if isinstance(value, StatePredicate): return {'atom': {'state': dict(column=str(_wide(value.column)), value=_enum(value.state, CellState))}}
    if isinstance(value, Comparison): return {'atom': {'compare': dict(column=str(_wide(value.column)), op=_enum(value.op, CompareOperator), value=logical.atom_wire(value.value))}}
    raise TypeError('Expected typed predicate')


def _mutation(value: Mutation, limit: int = LIMITS['catalog_action_bytes']) -> object:
    budget = _WireBudget(limit)
    predicates = None
    if isinstance(value, Insert):
        if not 1 <= len(value.rows) <= 1024: raise ValueError('Invalid insert row count')
        action: object = {'insert': [_assignments(row, budget) for row in value.rows]}
    elif isinstance(value, (Update, Delete)):
        action = {'update': _assignments(value.assignments, budget)} if isinstance(value, Update) else {'delete': {}}
        if value.predicate is not None:
            if len(value.predicate) > 64: raise ValueError('Too many predicate instructions')
            predicates = [budget.take(_predicate(item)) for item in value.predicate]
    else: raise TypeError('Expected typed mutation')
    return dict(action=action, predicate=predicates)



def _mutation_value(value: object) -> Mutation:
    """Decode saved handler work without changing its original typed intent."""
    document = _object(value, 'action predicate')
    def assignments(raw: object) -> tuple[Assignment, ...]:
        if not isinstance(raw, list) or len(raw) > 128: raise ValueError('Invalid assignments')
        result = []
        for entry in raw:
            item = _object(entry, 'column value'); tag, payload = _variant(item['value'])
            if tag == 'default':
                _object(payload, ''); cell: logical.Cell | Default = Default.VALUE
            elif tag == 'cell': cell = logical.cell_from_wire(payload)
            else: raise ValueError('Invalid assignment value')
            result.append(Assignment(_decimal(item['column']), cell))
        return tuple(result)
    predicate = None
    if document['predicate'] is not None:
        raw = document['predicate']
        if not isinstance(raw, list) or not 1 <= len(raw) <= 64: raise ValueError('Invalid predicate instructions')
        instructions: list[Predicate] = []
        for instruction in raw:
            tag, payload = _variant(instruction)
            if tag == 'atom':
                tag, payload = _variant(payload)
                if tag == 'all': _object(payload, ''); instructions.append(BooleanOperator.ALL)
                elif tag == 'state':
                    item = _object(payload, 'column value')
                    instructions.append(StatePredicate(_decimal(item['column']), CellState(item['value'])))
                elif tag == 'compare':
                    item = _object(payload, 'column op value')
                    instructions.append(Comparison(_decimal(item['column']), CompareOperator(item['op']), logical.atom_from_wire(item['value'])))
                else: raise ValueError('Invalid predicate atom')
            else:
                _object(payload, ''); operator = BooleanOperator(tag)
                if operator is BooleanOperator.ALL: raise ValueError('Invalid predicate operator')
                instructions.append(operator)
        predicate = tuple(instructions)
    tag, payload = _variant(document['action'])
    if tag == 'insert':
        if predicate is not None or not isinstance(payload, list) or not 1 <= len(payload) <= 1024: raise ValueError('Invalid insert rows')
        result: Mutation = Insert(tuple(assignments(row) for row in payload))
    elif tag == 'update': result = Update(assignments(payload), predicate)
    elif tag == 'delete': _object(payload, ''); result = Delete(predicate)
    else: raise ValueError('Invalid mutation action')
    if _mutation(result) != value: raise ValueError('Invalid saved mutation')
    return result


def _change(value: Change) -> object:
    if isinstance(value, SetIntegrity): return {'integrity': value.schema._wire()}
    if isinstance(value, AddColumn): return {'add': _column(value.name, value.type, value.nullable, value.default, value.max_characters, value.encoding, value.collation, value.semantics)}
    column = str(_wide(value.column))
    if isinstance(value, DropColumn): return {'drop': column}
    if isinstance(value, RenameColumn): return {'rename': dict(column=column, name=_name(value.name))}
    if isinstance(value, SetDefault): return {'default': dict(column=column, value=None if value.value is None else logical.cell_wire(value.value))}
    if isinstance(value, SetNullable): return {'nullable': dict(column=column, value=_boolean(value.nullable))}
    if isinstance(value, SetPhysical): return {'physical': dict(column=column, encoding=_enum(value.encoding, Encoding), collation=_enum(value.collation, Collation), semantics=None if value.semantics is None else value.semantics._wire())}
    if isinstance(value, SetType): return {'type': dict(column=column, type=logical.type_wire(value.type), max_characters=None if value.max_characters is None else integer(value.max_characters, 'characters', maximum=0xffffffff))}
    raise TypeError('Expected typed schema change')


@dataclass(frozen=True, slots=True)
class Connection:
    scope: Scope
    audience: int
    branch: int = 1
    role: int | None = None
    def __post_init__(self) -> None:
        if not isinstance(self.scope, Scope): raise TypeError('Expected catalog scope')
        integer(self.audience, 'audience'); _wide(self.branch, 'branch')
        if self.role is not None: integer(self.role, 'role', minimum=0)
    def _wire(self, principal: int) -> dict[str, Any]:
        return dict(scope=self.scope._wire(), branch=str(self.branch), audience=self.audience,
                    principal=integer(principal, 'principal', minimum=0), role=self.role)


def _connection(value: object) -> tuple[Connection, int]:
    value = _object(value, 'scope branch audience principal role')
    return (Connection(_scope(value['scope']), value['audience'], _decimal(value['branch']), value['role']),
            integer(value['principal'], 'principal', minimum=0))


@dataclass(frozen=True, slots=True)
class ObjectIdentity:
    scope: Scope
    branch: int
    object_id: int
    def __post_init__(self) -> None:
        if not isinstance(self.scope, Scope): raise TypeError('Expected catalog scope')
        _wide(self.branch); _wide(self.object_id)
    def _wire(self) -> dict[str, Any]:
        return dict(scope=self.scope._wire(), branch=str(self.branch), object=str(self.object_id))


def _object_identity(value: object) -> ObjectIdentity:
    value = _object(value, 'scope branch object')
    return ObjectIdentity(_scope(value['scope']), _decimal(value['branch']), _decimal(value['object']))


@dataclass(frozen=True, slots=True)
class Position:
    partition: int
    next_lsn: int
    def __post_init__(self) -> None: _wide(self.partition); _wide(self.next_lsn, minimum=0)
    def _wire(self) -> dict[str, str]: return dict(partition=str(self.partition), next_lsn=str(self.next_lsn))


def _position(value: object) -> Position:
    value = _object(value, 'partition next_lsn')
    return Position(_decimal(value['partition']), _decimal(value['next_lsn'], 0))


@dataclass(frozen=True, slots=True)
class Interpretation:
    object: ObjectIdentity
    revision: int
    digest: str


def _interpretation(value: object) -> Interpretation:
    value = _object(value, 'object revision digest')
    return Interpretation(_object_identity(value['object']), _decimal(value['revision']), _digest(value['digest']))


@dataclass(frozen=True, slots=True)
class Content:
    bytes: int
    sha256: str


def _content(value: object) -> Content:
    value = _object(value, 'bytes sha256')
    return Content(_decimal(value['bytes']), _digest(value['sha256']))


@dataclass(frozen=True, slots=True)
class StoredDefinition:
    interpretation: Interpretation
    content: Content
    schema_fingerprint: str
    retired: bool


def _stored(value: object) -> StoredDefinition:
    value = _object(value, 'interpretation content schema_fingerprint retired')
    result = StoredDefinition(_interpretation(value['interpretation']), _content(value['content']),
                              _digest(value['schema_fingerprint']), _boolean(value['retired']))
    if result.content.sha256 != result.interpretation.digest: raise ValueError('Changed stored interpretation')
    return result


def _pairs(items: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, item in items:
        if key in result: raise ValueError('Repeated saved field')
        result[key] = item
    return result


def _saved(input: str) -> Any:
    return json.loads(_text(input, LIMITS['catalog_action_bytes']), object_pairs_hook=_pairs)


@dataclass(frozen=True, slots=True)
class _Saved:
    _data: str = field(repr=False)
    def __post_init__(self) -> None: self._validate(self._wire())
    def _validate(self, value: Any) -> None: raise NotImplementedError
    def _wire(self) -> Any: return _saved(self._data)
    def save(self) -> str: return self._data


@dataclass(frozen=True, slots=True)
class Basis(_Saved):
    """Complete original name and interpretation binding; saving grants no rights."""
    @classmethod
    def restore(cls, saved: str) -> Basis: return cls(saved)
    def _validate(self, value: Any) -> None:
        value = _object(value, 'definition connection namespace name interpretation')
        _definition(value['definition']); connection, _ = _connection(value['connection'])
        integer(value['namespace'], 'namespace'); _name(value['name'])
        stored = _stored(value['interpretation'])
        if (stored.retired or stored.interpretation.object.scope != connection.scope or
            stored.interpretation.object.branch != connection.branch): raise ValueError('Foreign prepared binding')
    @property
    def object_id(self) -> int: return self.interpretation.interpretation.object.object_id
    @property
    def interpretation(self) -> StoredDefinition: return _stored(self._wire()['interpretation'])
    @property
    def connection(self) -> Connection: return _connection(self._wire()['connection'])[0]
    @property
    def principal(self) -> int: return _connection(self._wire()['connection'])[1]
    @property
    def namespace(self) -> int: return integer(self._wire()['namespace'], 'namespace')
    @property
    def name(self) -> str: return _name(self._wire()['name'])


@dataclass(frozen=True, slots=True)
class Metadata:
    basis: Basis
    schema: Schema
    authorization: int
    position: Position
    changed_lsn: int
    row_count: int


def _metadata(value: object) -> Metadata:
    value = _object(value, 'binding schema authorization position changed_lsn row_count')
    basis = Basis.restore(encode(value['binding']).decode()); schema = _schema(value['schema'])
    if schema.object_id != basis.object_id: raise ValueError('Metadata schema changed its object')
    return Metadata(basis, schema, integer(value['authorization'], 'authorization'), _position(value['position']),
                    _decimal(value['changed_lsn'], 0), _decimal(value['row_count'], 0))


@dataclass(frozen=True, slots=True)
class Identity:
    operation: int
    namespace: int = 1
    def __post_init__(self) -> None: _wide(self.operation); integer(self.namespace, 'namespace')


class Kind(str, Enum):
    CREATE = 'create'
    ALTER = 'alter'
    RENAME = 'rename'
    DROP = 'drop'
    INSERT = 'insert'
    UPDATE = 'update'
    DELETE = 'delete'


def _binding(value: object) -> dict[str, Any]:
    value = _object(value, 'definition identity target action expected_definition expected_data intent prerequisite')
    _definition(value['definition']); _digest(value['intent']); action = Kind(value['action'])
    identity = _object(value['identity'], 'scope principal operation'); scope = _scope(identity['scope'])
    integer(identity['principal'], 'principal', minimum=0); _decimal(identity['operation'])
    target = _object_identity(value['target'])
    if target.scope != scope: raise ValueError('Foreign operation target')
    expected = None if value['expected_definition'] is None else _interpretation(value['expected_definition'])
    if (expected is None) != (action == Kind.CREATE) or (expected and expected.object != target): raise ValueError('Changed expected definition')
    if value['expected_data'] is not None:
        _position(value['expected_data'])
        if action == Kind.CREATE: raise ValueError('CREATE has no previous data position')
    if value['prerequisite'] is not None:
        # This opaque native guard is retained exactly, never interpreted as authority
        # by Python. The shared native owner validates its complete signed contract.
        guard = _object(value['prerequisite'], 'subject requirements selectable')
        if not isinstance(guard['subject'], dict) or not isinstance(guard['requirements'], list): raise ValueError('Invalid native guard')
        if guard['selectable'] is not None: integer(guard['selectable'], 'selectable')
    return value


def _assertion(value: object) -> dict[str, Any]:
    value = _object(value, 'definition connection operation namespace name action expected intent')
    _definition(value['definition']); connection, _ = _connection(value['connection'])
    _decimal(value['operation']); integer(value['namespace'], 'namespace'); _name(value['name']); _digest(value['intent'])
    if value['action'] not in ('create_if_not_exists', 'drop_if_exists'): raise ValueError('Invalid assertion action')
    expected = None if value['expected'] is None else _interpretation(value['expected'])
    if (expected is None) != (value['action'] == 'drop_if_exists'): raise ValueError('Invalid name condition')
    if expected and (expected.object.scope != connection.scope or expected.object.branch != connection.branch): raise ValueError('Foreign condition')
    return value


@dataclass(frozen=True, slots=True)
class SavedIntent(_Saved):
    @classmethod
    def restore(cls, saved: str) -> SavedIntent: return cls(saved)
    def _validate(self, value: Any) -> None:
        tag, payload = _variant(value)
        if tag == 'name_assertion': _assertion(payload)
        elif tag == 'table':
            payload = _object(payload, 'definition namespace bytes'); _definition(payload['definition'])
            integer(payload['namespace'], 'namespace'); _hex(payload['bytes'], LIMITS['catalog_intent_bytes'])
        else: raise ValueError('Invalid saved Table work')


@dataclass(frozen=True, slots=True)
class Reference(_Saved):
    @classmethod
    def restore(cls, saved: str) -> Reference: return cls(saved)
    def _validate(self, value: Any) -> None:
        tag, payload = _variant(value)
        if tag == 'name_assertion': _assertion(payload)
        elif tag == 'table':
            payload = _object(payload, 'definition connection namespace binding content')
            _definition(payload['definition']); connection, principal = _connection(payload['connection'])
            integer(payload['namespace'], 'namespace'); _content(payload['content']); bound = _binding(payload['binding'])
            target = _object_identity(bound['target'])
            if (target.scope != connection.scope or target.branch != connection.branch or
                bound['identity']['principal'] != principal): raise ValueError('Foreign recovery reference')
        else: raise ValueError('Invalid recovery reference')
    @property
    def kind(self) -> str: return _variant(self._wire())[0]
    @property
    def operation(self) -> int:
        kind, value = _variant(self._wire())
        return _decimal(value['binding']['identity']['operation'] if kind == 'table' else value['operation'])
    def _binding(self) -> dict[str, Any]:
        kind, value = _variant(self._wire())
        return _binding(value['binding']) if kind == 'table' else _assertion(value)


@dataclass(frozen=True, slots=True)
class Intent:
    digest: str
    namespace: int
    operation: int
    kind: str
    saved: SavedIntent
    _binding_data: str = field(repr=False)
    def _id(self) -> object: return dict(definition=DEFINITION, digest=_digest(self.digest))
    def _binding(self) -> Any: return _saved(self._binding_data)


def _summary(value: object, saved: SavedIntent, connection: Connection, principal: int) -> Intent:
    value = _object(value, 'id namespace binding'); identity = _object(value['id'], 'definition digest')
    _definition(identity['definition']); namespace = integer(value['namespace'], 'namespace')
    tag, bound = _variant(value['binding'])
    if tag == 'table':
        bound = _binding(bound); operation = _decimal(bound['identity']['operation']); target = _object_identity(bound['target'])
        if target.scope != connection.scope or target.branch != connection.branch or bound['identity']['principal'] != principal: raise ValueError('Foreign loaded work')
    elif tag == 'name_assertion':
        bound = _assertion(bound); operation = _decimal(bound['operation'])
        if bound['connection'] != connection._wire(principal) or bound['namespace'] != namespace: raise ValueError('Foreign assertion work')
    else: raise ValueError('Unknown work kind')
    saved_tag, original = _variant(saved._wire())
    if saved_tag != tag or original['namespace'] != namespace or (tag == 'name_assertion' and original != bound): raise ValueError('Changed saved work')
    return Intent(_digest(identity['digest']), namespace, operation, tag, saved, encode(bound).decode())


@dataclass(frozen=True, slots=True)
class Compiled:
    intent: Intent
    saved: SavedIntent


def _compiled(value: object, connection: Connection, principal: int, identity: Identity) -> Compiled:
    value = _object(value, 'summary saved'); saved = SavedIntent.restore(encode(value['saved']).decode())
    intent = _summary(value['summary'], saved, connection, principal)
    if intent.namespace != identity.namespace or intent.operation != identity.operation: raise ValueError('Changed compiled identity')
    return Compiled(intent, saved)


@dataclass(frozen=True, slots=True)
class Commit:
    definition: StoredDefinition
    position: Position
    matched: int
    affected: int
    live_rows: int


@dataclass(frozen=True, slots=True)
class Counts:
    matched: int
    changed: int
    def __post_init__(self) -> None:
        _wide(self.matched, minimum=0); _wide(self.changed, minimum=0)
        if self.changed > self.matched: raise ValueError('Changed count exceeds matched count')


@dataclass(frozen=True, slots=True)
class Observation:
    kind: str
    state: str
    reference: Reference
    commit: Commit | None = None
    phase: str | None = None
    reason: str | None = None
    position: Position | None = None


_ddl_reasons = ('none', 'name_conflict', 'object_conflict', 'stale_definition', 'stale_data', 'dependency', 'constraint', 'rewrite_required', 'work_limit')
_row_reasons = ('none', 'definition_changed', 'data_changed', 'duplicate_key', 'missing_row', 'invalid_rows', 'work_limit', 'check_violation')


def _one_of(value: object, options: tuple[str, ...]) -> str:
    if not isinstance(value, str) or value not in options: raise ValueError('Unknown lifecycle variant')
    return value


def _observation(value: object, original: Reference) -> Observation:
    kind, tagged = _variant(value); state, record = _variant(tagged); expected = original._binding()
    expected_kind = 'name_assertion' if original.kind == 'name_assertion' else 'rows' if expected['action'] in ('insert', 'update', 'delete') else 'ddl'
    if kind != expected_kind: raise ValueError('Changed observation kind')
    if state == 'not_observed':
        _object(record, ''); return Observation(original.kind, state, original)
    if state == 'finalizing':
        if kind != 'ddl': raise ValueError('Invalid finalizing operation kind')
        final = _object(record, 'evidence operation')
        if not isinstance(final['operation'], dict) or final['operation'].get('binding') != expected: raise ValueError('Changed finalizing binding')
        if final['operation'].get('requires_settlement') is not True or final['operation'].get('phase') not in ('admitted', 'ready'): raise ValueError('Invalid finalizing operation phase')
        commit = _observation({'ddl': {'committed': final['evidence']}}, original).commit
        return Observation(original.kind, 'finalizing', original, commit=commit)
    if not isinstance(record, dict) or record.get('binding') != expected: raise ValueError('Changed original operation binding')
    if kind == 'name_assertion':
        if state != 'outcome': raise ValueError('Invalid name assertion state')
        record = _object(record, 'binding position state reason')
        state = _one_of(record['state'], ('unchanged', 'rejected', 'cancelled'))
        reason = _one_of(record['reason'], ('none', 'condition_changed'))
        if (state == 'rejected') != (reason != 'none'): raise ValueError('Inconsistent name outcome')
        return Observation(original.kind, state, original, reason=reason, position=_position(record['position']))
    if state == 'committed':
        record = _object(record, 'binding resulting outcome transaction')
        if record['transaction'] is not None: raise ValueError('Unexpected transaction commit evidence')
        outcome = _object(record['outcome'], 'position matched affected live_rows')
        commit = Commit(_stored(record['resulting']), _position(outcome['position']), _decimal(outcome['matched'], 0),
                        _decimal(outcome['affected'], 0), _decimal(outcome['live_rows'], 0))
        if commit.affected > commit.matched or commit.definition.interpretation.object != _object_identity(expected['target']): raise ValueError('Changed commit evidence')
        return Observation(original.kind, state, original, commit=commit)
    _one_of(state, ('admitted', 'rejected', 'cancelled'))
    record = _object(record, 'binding intent phase reason' + (' basis' if kind == 'rows' else ' dependency_steps protected_columns requires_settlement closing')); _content(record['intent'])
    phase = _one_of(record['phase'], ('admitted', 'rejected', 'cancelled') if kind == 'rows' else ('admitted', 'ready', 'rejected', 'cancelled', 'settled'))
    reason = _one_of(record['reason'], _row_reasons if kind == 'rows' else _ddl_reasons)
    if (state == 'admitted' and phase not in ('admitted', 'ready', 'settled')) or (state != 'admitted' and state != phase): raise ValueError('Inconsistent operation phase')
    if kind == 'rows':
        basis = _object(record['basis'], 'interpretation position changed_lsn')
        _interpretation(basis['interpretation']); _position(basis['position']); _decimal(basis['changed_lsn'], 0)
    return Observation(original.kind, state, original, phase=phase, reason=reason)


@dataclass(frozen=True, slots=True)
class CurrentBasis:
    definition: StoredDefinition
    position: Position
    changed_lsn: int
    row_count: int


@dataclass(frozen=True, slots=True)
class Preview:
    kind: str
    intent: Intent
    position: Position
    current: CurrentBasis | Interpretation | None
    reason: str | None = None
    work: str | None = None
    rebuild_key: bool | None = None
    schema_fingerprint: str | None = None
    matches: bool | None = None


def _preview(value: object, intent: Intent) -> Preview:
    kind, raw = _variant(value)
    if not isinstance(raw, dict) or raw.get('binding') != intent._binding(): raise ValueError('Changed preview binding')
    if (kind == 'name_assertion') != (intent.kind == 'name_assertion'): raise ValueError('Changed preview kind')
    if kind == 'name_assertion':
        raw = _object(raw, 'binding position current matches')
        return Preview(kind, intent, _position(raw['position']), None if raw['current'] is None else _interpretation(raw['current']), matches=_boolean(raw['matches']))
    _one_of(kind, ('ddl', 'rows'))
    raw = _object(raw, 'binding directory_position current reason' + (' work rebuild_key schema_fingerprint' if kind == 'ddl' else ''))
    current = None
    if raw['current'] is not None:
        basis = _object(raw['current'], 'interpretation position changed_lsn row_count')
        current = CurrentBasis(_stored(basis['interpretation']), _position(basis['position']), _decimal(basis['changed_lsn'], 0), _decimal(basis['row_count'], 0))
    elif kind == 'rows': raise ValueError('Missing row preview basis')
    reason = _one_of(raw['reason'], _ddl_reasons if kind == 'ddl' else ('none', 'stale_definition', 'stale_data', 'object_conflict'))
    if kind == 'rows': return Preview(kind, intent, _position(raw['directory_position']), current, reason=reason)
    return Preview(kind, intent, _position(raw['directory_position']), current, reason,
                   None if raw['work'] is None else _one_of(raw['work'], ('metadata', 'validate_rows', 'rewrite_rows')),
                   _boolean(raw['rebuild_key']), None if raw['schema_fingerprint'] is None else _digest(raw['schema_fingerprint']))


def _operation(value: Operation) -> object:
    if isinstance(value, Create): return {'create': dict(schema=value.schema._wire(), if_not_exists=_boolean(value.if_not_exists))}
    if isinstance(value, Drop): return {'drop': dict(basis=None if value.basis is None else value.basis._wire(), if_exists=_boolean(value.if_exists))}
    if isinstance(value, Rename): return {'rename': dict(basis=value.basis._wire(), name=_name(value.name))}
    if isinstance(value, Alter): return {'alter': dict(basis=value.basis._wire(), change=_change(value.change))}
    if isinstance(value, Mutate): return {'mutate': dict(basis=value.basis._wire(), mutation=_mutation(value.mutation), ingestion=_one_of(value.ingestion, ('point', 'bulk')))}
    raise TypeError('Expected typed catalog operation')


@dataclass(frozen=True, slots=True)
class Capabilities:
    version: int
    definition: str
    max_columns: int
    max_rows: int
    max_sql_bytes: int
    max_intent_bytes: int
    max_action_bytes: int
    metadata_page_entries: int
    resident_intents: int


def _capabilities(value: object) -> Capabilities:
    value = _object(value, 'version definition max_columns max_rows max_sql_bytes max_intent_bytes max_action_bytes metadata_page_entries resident_intents')
    checked: dict[str, Any] = {key: _definition(item) if key == 'definition' else integer(item, key) for key, item in value.items()}
    return Capabilities(**checked)


@dataclass(frozen=True, slots=True)
class Configuration:
    scope: Scope
    branch: int
    partition: int
    audience: int
    authority: AuthorityProfile
    database_name: str
    initial_schema_name: str


@dataclass(frozen=True, slots=True)
class Description:
    configuration: Configuration
    subject: Subject
    policy_revision: int


def _description(value: object, connection: Connection, principal: int) -> Description:
    value = _object(value, 'configuration subject policy_revision')
    config = _object(value['configuration'], 'scope branch partition audience authority database_name initial_schema_name')
    authority = AuthorityProfile(**_object(config['authority'], 'database_domain schema_domain table_domain stream_domain queue_domain kv_domain database initial_schema initial_schema_authority'))
    configuration = Configuration(_scope(config['scope']), _decimal(config['branch']), _decimal(config['partition']), integer(config['audience'], 'audience'),
                                  authority, _text(config['database_name'], 63), _text(config['initial_schema_name'], 63))
    raw = _object(value['subject'], 'principal login_role role credential_epoch audience context')
    if not isinstance(raw['context'], list) or len(raw['context']) != 32: raise ValueError('Invalid subject context')
    subject = Subject(raw['principal'], raw['login_role'], raw['role'], raw['credential_epoch'], raw['audience'],
                      bytes(integer(byte, 'context byte', minimum=0, maximum=255) for byte in raw['context']))
    if (configuration.scope != connection.scope or configuration.branch != connection.branch or configuration.audience != connection.audience or
        subject.principal != principal or subject.audience != connection.audience or subject.role != (connection.role if connection.role is not None else subject.login_role)):
        raise ValueError('Changed catalog connection or subject')
    return Description(configuration, subject, integer(value['policy_revision'], 'policy revision', minimum=0))


@dataclass(frozen=True, slots=True)
class Namespace:
    scope: Scope
    id: int
    authorization: int
    name: str
    revision: int
    retired: bool


def _namespace(value: object) -> Namespace:
    value = _object(value, 'scope id authorization name revision retired')
    return Namespace(_scope(value['scope']), integer(value['id'], 'namespace'), integer(value['authorization'], 'authorization'),
                      _name(value['name']), integer(value['revision'], 'revision'), _boolean(value['retired']))


@dataclass(frozen=True, slots=True)
class Entry:
    interpretation: Interpretation
    namespace: int
    name: str
    position: Position
    changed_lsn: int


def _entry(value: object) -> Entry:
    value = _object(value, 'interpretation namespace name position changed_lsn')
    return Entry(_interpretation(value['interpretation']), integer(value['namespace'], 'namespace'), _name(value['name']),
                 _position(value['position']), _decimal(value['changed_lsn'], 0))


@dataclass(frozen=True, slots=True)
class Cursor(_Saved):
    @classmethod
    def restore(cls, saved: str) -> Cursor: return cls(saved)
    def _validate(self, value: Any) -> None:
        value = _object(value, 'definition connection selection position after')
        _definition(value['definition']); _connection(value['connection']); position = _position(value['position'])
        after = _decimal(value['after']); kind, payload = _variant(value['selection'])
        if kind == 'namespaces': _object(payload, ''); integer(after, 'after namespace')
        elif kind in ('tables', 'resources'): integer(payload, 'namespace')
        else: raise ValueError('Invalid directory selection')
        if position.next_lsn == 0: raise ValueError('Invalid directory position')
    def _check(self, connection: Connection, principal: int, selection: object) -> dict[str, Any]:
        value = _object(self._wire(), 'definition connection selection position after')
        if value['connection'] != connection._wire(principal) or value['selection'] != selection: raise ValueError('Foreign directory cursor')
        return value


@dataclass(frozen=True, slots=True)
class Page(Generic[W]):
    entries: tuple[W, ...]
    next: Cursor | None
    position: Position
    consistency: Literal['independent'] | None = None


def _page(value: object, connection: Connection, principal: int, namespace: int | None, previous: Cursor | None) -> Page[Namespace | Entry]:
    value = _object(value, 'entries next position' + ('' if namespace is None else ' consistency'))
    if not isinstance(value['entries'], list) or len(value['entries']) != 8: raise ValueError('Expected eight optional directory slots')
    selection: dict[str, Any] = {'namespaces': {}} if namespace is None else {'tables': namespace}
    prior = None if previous is None else previous._check(connection, principal, selection)
    position = _position(value['position']); cursor = None if value['next'] is None else Cursor.restore(encode(value['next']).decode())
    after = 0 if prior is None else _decimal(prior['after']); last = after; ended = False
    entries: list[Namespace | Entry] = []
    entry: Namespace | Entry
    for item in value['entries']:
        if item is None: ended = True; continue
        if ended: raise ValueError('Directory page contains a hole')
        if namespace is None:
            entry = _namespace(item); identity = entry.id
            if entry.scope != connection.scope: raise ValueError('Foreign namespace entry')
        else:
            entry = _entry(item); identity = entry.interpretation.object.object_id
            if (entry.namespace != namespace or entry.interpretation.object.scope != connection.scope or
                entry.interpretation.object.branch != connection.branch): raise ValueError('Foreign Table entry')
        if identity <= last: raise ValueError('Directory ordering changed')
        entries.append(entry)
        last = identity
    if prior is not None and prior['position'] != value['position']: raise ValueError('Directory continuation changed its cut')
    if cursor:
        tail = cursor._check(connection, principal, selection)
        if tail['position'] != value['position'] or _decimal(tail['after']) < last or _decimal(tail['after']) <= after: raise ValueError('Invalid directory continuation')
    consistency: Literal['independent'] | None = None
    if namespace is not None:
        _one_of(value['consistency'], ('independent',)); consistency = 'independent'
    return Page(tuple(entries), cursor, position, consistency)


@dataclass(frozen=True, slots=True)
class SnapshotOwner(_Saved):
    @classmethod
    def restore(cls, saved: str) -> SnapshotOwner: return cls(saved)
    def _validate(self, value: Any) -> None:
        value = _object(value, 'definition connection object operation'); _definition(value['definition'])
        connection, _ = _connection(value['connection']); object_id = _object_identity(value['object']); _decimal(value['operation'])
        if object_id.scope != connection.scope or object_id.branch != connection.branch: raise ValueError('Foreign snapshot owner')
    @property
    def operation(self) -> int: return _decimal(self._wire()['operation'])
    @property
    def object(self) -> ObjectIdentity: return _object_identity(self._wire()['object'])
    def _check(self, connection: Connection, principal: int) -> None:
        if self._wire()['connection'] != connection._wire(principal): raise ValueError('Foreign snapshot connection')


@dataclass(frozen=True, slots=True)
class SnapshotAcquisition(_Saved):
    @classmethod
    def restore(cls, saved: str) -> SnapshotAcquisition: return cls(saved)
    def _validate(self, value: Any) -> None:
        value = _object(value, 'owner expected'); SnapshotOwner.restore(encode(value['owner']).decode())
        if _position(value['expected']).next_lsn == 0: raise ValueError('Expected an accepted position')
    @property
    def owner(self) -> SnapshotOwner: return SnapshotOwner.restore(encode(self._wire()['owner']).decode())
    @property
    def expected(self) -> Position: return _position(self._wire()['expected'])


@dataclass(frozen=True, slots=True)
class Snapshot(_Saved):
    @classmethod
    def restore(cls, saved: str) -> Snapshot: return cls(saved)
    def _validate(self, value: Any) -> None:
        value = _object(value, 'owner content'); SnapshotOwner.restore(encode(value['owner']).decode()); _content(value['content'])
    @property
    def owner(self) -> SnapshotOwner: return SnapshotOwner.restore(encode(self._wire()['owner']).decode())
    @property
    def content(self) -> Content: return _content(self._wire()['content'])


@dataclass(frozen=True, slots=True)
class ReadAuthority:
    database: int
    schema: int
    table: int


def _authority(value: object) -> ReadAuthority:
    value = _object(value, 'database schema table')
    result = ReadAuthority(**{key: integer(item, key) for key, item in value.items()})
    if len({result.database, result.schema, result.table}) != 3: raise ValueError('Invalid read authority')
    return result


@dataclass(frozen=True, slots=True)
class SnapshotStatus:
    owner: SnapshotOwner
    current_interpretation: Interpretation
    current_position: Position
    retired: bool
    snapshot: Snapshot | None
    released: bool
    authority: ReadAuthority


def _snapshot_status(value: object, owner: SnapshotOwner) -> SnapshotStatus:
    value = _object(value, 'owner current_interpretation current_position retired snapshot released authority')
    snapshot = None if value['snapshot'] is None else Snapshot.restore(encode(value['snapshot']).decode())
    interpretation = _interpretation(value['current_interpretation'])
    if value['owner'] != owner._wire() or interpretation.object != owner.object or (snapshot and snapshot.owner._wire() != owner._wire()): raise ValueError('Changed snapshot owner')
    released = _boolean(value['released'])
    if released and snapshot is None: raise ValueError('Release without snapshot evidence')
    return SnapshotStatus(owner, interpretation, _position(value['current_position']), _boolean(value['retired']), snapshot, released, _authority(value['authority']))


@dataclass(frozen=True, slots=True)
class SnapshotMetadata:
    snapshot: Snapshot
    definition: StoredDefinition
    accepted: Position
    changed_lsn: int
    row_count: int
    schema: Schema
    authority: ReadAuthority


def _snapshot_metadata(value: object, snapshot: Snapshot) -> SnapshotMetadata:
    value = _object(value, 'snapshot interpretation accepted changed_lsn row_count schema authority')
    stored = _stored(value['interpretation']); schema = _schema(value['schema'])
    if (value['snapshot'] != snapshot._wire() or stored.interpretation.object != snapshot.owner.object or
        schema.object_id != snapshot.owner.object.object_id): raise ValueError('Changed retained source')
    return SnapshotMetadata(snapshot, stored, _position(value['accepted']), _decimal(value['changed_lsn'], 0), _decimal(value['row_count'], 0), schema, _authority(value['authority']))


@dataclass(frozen=True, slots=True)
class HistoryOperation:
    scope: Scope
    principal: int
    operation: int
    def _wire(self) -> dict[str, object]:
        return dict(scope=self.scope._wire(), principal=integer(self.principal, 'principal', minimum=0), operation=str(_wide(self.operation)))


def _history_operation(value: object) -> HistoryOperation:
    value = _object(value, 'scope principal operation')
    return HistoryOperation(_scope(value['scope']), integer(value['principal'], 'principal', minimum=0), _decimal(value['operation']))


@dataclass(frozen=True, slots=True)
class HistoryDirectory:
    content: Content
    count: int
    def _wire(self) -> dict[str, object]:
        return dict(content=dict(bytes=str(_wide(self.content.bytes)), sha256=_digest(self.content.sha256)), count=str(_wide(self.count)))


def _history_directory(value: object) -> HistoryDirectory:
    value = _object(value, 'content count')
    return HistoryDirectory(_content(value['content']), _decimal(value['count']))


@dataclass(frozen=True, slots=True)
class HistoryCommonCut:
    transaction: HistoryOperation
    acquired: Position
    sources: Content
    source_count: int
    def _wire(self) -> dict[str, object]:
        return dict(transaction=self.transaction._wire(), acquired=self.acquired._wire(),
                    sources=dict(bytes=str(_wide(self.sources.bytes)), sha256=_digest(self.sources.sha256)), source_count=str(_wide(self.source_count)))


def _history_cut(value: object) -> HistoryCommonCut:
    value = _object(value, 'transaction acquired sources source_count')
    return HistoryCommonCut(_history_operation(value['transaction']), _position(value['acquired']), _content(value['sources']), _decimal(value['source_count']))


@dataclass(frozen=True, slots=True)
class HistoryBudget:
    operations: int = 1_000_000
    bytes: int = 4_294_967_296
    pending: int = 1024
    charge_bytes: int = 4608
    def _wire(self) -> dict[str, str]:
        return {key: str(_wide(getattr(self, key))) for key in ('operations', 'bytes', 'pending', 'charge_bytes')}


@dataclass(frozen=True, slots=True)
class HistorySelection(_Saved):
    """Immutable selection directory; this does not retain its data."""
    @classmethod
    def restore(cls, saved: str) -> HistorySelection: return cls(saved)
    def _validate(self, value: Any) -> None:
        value = _object(value, 'definition owner branch directory'); _definition(value['definition'])
        _history_operation(value['owner']); _decimal(value['branch'])
        if value['directory'] is not None: _history_directory(value['directory'])
    @property
    def owner(self) -> HistoryOperation: return _history_operation(self._wire()['owner'])
    @property
    def branch(self) -> int: return _decimal(self._wire()['branch'])
    @property
    def directory(self) -> HistoryDirectory | None:
        value = self._wire()['directory']
        return None if value is None else _history_directory(value)


@dataclass(frozen=True, slots=True)
class HistoryKey(_Saved):
    @classmethod
    def restore(cls, saved: str) -> HistoryKey: return cls(saved)
    def _validate(self, value: Any) -> None:
        value = _object(value, 'definition connection account token'); _definition(value['definition']); _connection(value['connection'])
        _hex(value['account'], 32, True); _hex(value['token'], 16, True)
    @property
    def account(self) -> bytes: return _hex(self._wire()['account'], 32, True)
    @property
    def token(self) -> bytes: return _hex(self._wire()['token'], 16, True)
    def _check(self, connection: Connection, principal: int) -> dict[str, Any]:
        value = _object(self._wire(), 'definition connection account token')
        if value['connection'] != connection._wire(principal): raise ValueError('Foreign history recovery connection')
        return value


@dataclass(frozen=True, slots=True)
class HistorySelectionStep(_Saved):
    """Save before dispatch; retrying selection is not retention acceptance."""
    @classmethod
    def restore(cls, saved: str) -> HistorySelectionStep: return cls(saved)
    def _validate(self, value: Any) -> None:
        value = _object(value, 'selection namespace name')
        HistorySelection.restore(encode(value['selection']).decode()); integer(value['namespace'], 'namespace'); _name(value['name'])
    @property
    def selection(self) -> HistorySelection: return HistorySelection.restore(encode(self._wire()['selection']).decode())
    @property
    def namespace(self) -> int: return integer(self._wire()['namespace'], 'namespace')
    @property
    def name(self) -> str: return _name(self._wire()['name'])


@dataclass(frozen=True, slots=True)
class HistoryIntent:
    operation: int
    namespace: int
    selection: HistoryDirectory
    common_key: HistoryKey | None
    common_cut: HistoryCommonCut | None


def _history_intent(value: object, key: HistoryKey) -> HistoryIntent:
    value = _object(value, 'definition connection namespace operation selection common'); _definition(value['definition'])
    if value['connection'] != key._wire()['connection']: raise ValueError('Changed history intent connection')
    common_key, common_cut = None, None
    if value['common'] is not None:
        common = _object(value['common'], 'key cut')
        common_key = HistoryKey.restore(encode(common['key']).decode()); common_cut = _history_cut(common['cut'])
    return HistoryIntent(_decimal(value['operation']), integer(value['namespace'], 'namespace'), _history_directory(value['selection']), common_key, common_cut)


@dataclass(frozen=True, slots=True)
class HistoryAcquisition(_Saved):
    """Complete original request, including selected directory and common cut."""
    @classmethod
    def restore(cls, saved: str) -> HistoryAcquisition: return cls(saved)
    def _validate(self, value: Any) -> None:
        if not isinstance(value, dict) or set(value) not in ({'key', 'intent'}, {'key', 'intent', 'budget'}): raise ValueError('Unexpected history acquisition fields')
        _history_intent(value['intent'], HistoryKey.restore(encode(value['key']).decode()))
        if 'budget' in value:
            budget = value['budget']
            if not isinstance(budget, dict) or not set(budget) <= {'operations', 'bytes', 'pending', 'charge_bytes'}: raise ValueError('Unexpected history budget fields')
            for limit in budget.values(): _decimal(limit)
    @property
    def key(self) -> HistoryKey: return HistoryKey.restore(encode(self._wire()['key']).decode())
    @property
    def intent(self) -> HistoryIntent: return _history_intent(self._wire()['intent'], self.key)


@dataclass(frozen=True, slots=True)
class HistoryControl(_Saved):
    @classmethod
    def restore(cls, saved: str) -> HistoryControl: return cls(saved)
    def _validate(self, value: Any) -> None:
        command, key = _variant(value); _one_of(command, ('advance', 'abandon', 'release')); HistoryKey.restore(encode(key).decode())
    @property
    def command(self) -> str: return _variant(self._wire())[0]
    @property
    def key(self) -> HistoryKey: return HistoryKey.restore(encode(_variant(self._wire())[1]).decode())


@dataclass(frozen=True, slots=True)
class HistoricalSnapshot:
    """Opaque selector, verified by the shared owner on every operation."""
    selector: str
    def __post_init__(self) -> None: _hex(self.selector, 297, True)
    def save(self) -> str: return encode(dict(selector=self.selector)).decode()
    @classmethod
    def restore(cls, saved: str) -> HistoricalSnapshot:
        return cls(_object(_saved(saved), 'selector')['selector'])


@dataclass(frozen=True, slots=True)
class HistoryBasis:
    definition: str
    snapshot: HistoricalSnapshot
    owner: HistoryOperation
    branch: int
    catalog_root: Content
    sources_root: Content
    source_count: int
    consistency: Literal['single_partition', 'independent', 'common_transaction']
    position: Position | None
    common_cut: HistoryCommonCut | None


def _history_basis(value: object, selected: HistoricalSnapshot | None = None) -> HistoryBasis:
    value = _object(value, 'selector definition owner branch catalog_root sources_root source_count consistency'); _definition(value['definition'])
    snapshot = HistoricalSnapshot(value['selector'])
    if selected is not None and snapshot != selected: raise ValueError('Changed historical snapshot')
    kind, payload = _variant(value['consistency'])
    if kind not in ('single_partition', 'independent', 'common_transaction'): raise ValueError('Unknown history consistency')
    position = _position(payload) if kind == 'single_partition' else None
    common = _history_cut(payload) if kind == 'common_transaction' else None
    if kind == 'independent': _object(payload, '')
    return HistoryBasis(value['definition'], snapshot, _history_operation(value['owner']), _decimal(value['branch']), _content(value['catalog_root']),
                        _content(value['sources_root']), _decimal(value['source_count']), cast(Literal['single_partition', 'independent', 'common_transaction'], kind), position, common)


@dataclass(frozen=True, slots=True)
class HistoryStatus:
    key: HistoryKey
    intent: HistoryIntent
    admitted: Position
    revision: Position
    phase: Literal['acquiring', 'verifying', 'published', 'abandoning', 'cancelled', 'releasing', 'released']
    retained: HistoryDirectory | None
    after: int | None
    inflight: int | None
    verified_after: int | None
    policy_epoch: int | None
    released_after: int | None
    basis: HistoryBasis | None


def _history_status(value: object, key: HistoryKey, original: HistoryAcquisition | None = None) -> HistoryStatus | None:
    if value is None: return None
    value = _object(value, 'key intent admitted revision phase retained after inflight verified_after policy_epoch released_after snapshot')
    if value['key'] != key._wire() or (original is not None and value['intent'] != original._wire()['intent']): raise ValueError('Changed original history acquisition')
    intent = _history_intent(value['intent'], key)
    phase = value['phase']
    if phase not in ('acquiring', 'verifying', 'published', 'abandoning', 'cancelled', 'releasing', 'released'): raise ValueError('Unknown history phase')
    published = phase in ('published', 'releasing', 'released')
    if published != (value['snapshot'] is not None): raise ValueError('Missing or premature history publication')
    if value['snapshot'] is not None:
        snapshot = _object(value['snapshot'], 'selector definition owner branch catalog_root sources_root source_count consistency')
        connection = value['key']['connection']; original_intent = value['intent']; common = original_intent['common']
        consistency, evidence = _variant(snapshot['consistency'])
        if (snapshot['owner'] != dict(scope=connection['scope'], principal=connection['principal'], operation=original_intent['operation']) or
            snapshot['branch'] != connection['branch'] or snapshot['source_count'] != original_intent['selection']['count'] or snapshot['catalog_root'] != original_intent['selection']['content'] or
            (common is not None and (consistency != 'common_transaction' or evidence != common['cut'])) or (common is None and consistency == 'common_transaction')):
            raise ValueError('Changed published history basis')
    def optional(name: str) -> int | None: return None if value[name] is None else _decimal(value[name], 0)
    return HistoryStatus(key, intent, _position(value['admitted']), _position(value['revision']), phase,
                         None if value['retained'] is None else _history_directory(value['retained']), optional('after'), optional('inflight'),
                         optional('verified_after'), optional('policy_epoch'), optional('released_after'),
                         None if value['snapshot'] is None else _history_basis(value['snapshot']))


@dataclass(frozen=True, slots=True)
class HistoryNamespace:
    scope: Scope
    id: int
    authorization: int
    name: str
    revision: int


def _history_namespace(value: object) -> HistoryNamespace:
    value = _object(value, 'scope id authorization name revision')
    return HistoryNamespace(_scope(value['scope']), integer(value['id'], 'namespace'), integer(value['authorization'], 'authorization'), _name(value['name']), _decimal(value['revision']))


@dataclass(frozen=True, slots=True)
class HistoryEntry:
    namespace: HistoryNamespace
    name: str
    definition: StoredDefinition
    accepted: Position
    catalog: Position


def _history_entry(value: object) -> HistoryEntry:
    value = _object(value, 'namespace name declaration accepted catalog')
    return HistoryEntry(_history_namespace(value['namespace']), _name(value['name']), _stored(value['declaration']), _position(value['accepted']), _position(value['catalog']))


@dataclass(frozen=True, slots=True)
class HistoryCursor(_Saved):
    @classmethod
    def restore(cls, saved: str) -> HistoryCursor: return cls(saved)
    def _validate(self, value: Any) -> None:
        value = _object(value, 'selector namespace directory after')
        HistoricalSnapshot(value['selector']); integer(value['namespace'], 'namespace'); _history_directory(value['directory']); _decimal(value['after'])
    @property
    def snapshot(self) -> HistoricalSnapshot: return HistoricalSnapshot(self._wire()['selector'])
    @property
    def namespace(self) -> int: return integer(self._wire()['namespace'], 'namespace')
    def _check(self, snapshot: HistoricalSnapshot, namespace: int) -> object:
        if self.snapshot != snapshot or self.namespace != namespace: raise ValueError('History cursor belongs to a different selection')
        return self._wire()


@dataclass(frozen=True, slots=True)
class HistoryPage:
    basis: HistoryBasis
    namespace: int
    entries: tuple[HistoryEntry, ...]
    next: HistoryCursor | None


def _history_page(value: object, snapshot: HistoricalSnapshot, scope: Scope, namespace: int, previous: HistoryCursor | None = None) -> HistoryPage:
    value = _object(value, 'snapshot namespace entries next'); basis = _history_basis(value['snapshot'], snapshot)
    if value['namespace'] != namespace or not isinstance(value['entries'], list) or len(value['entries']) > 8: raise ValueError('Changed history page scope or bound')
    entries = tuple(_history_entry(item) for item in value['entries'])
    if any(item.namespace.id != namespace or item.namespace.scope != scope for item in entries): raise ValueError('Changed history entry scope')
    cursor = None if value['next'] is None else HistoryCursor.restore(encode(value['next']).decode())
    if cursor:
        cursor._check(snapshot, namespace)
        native = cursor._wire()
        if _history_directory(native['directory']) != HistoryDirectory(basis.sources_root, basis.source_count) or (previous is not None and _decimal(native['after']) <= _decimal(previous._wire()['after'])):
            raise ValueError('Historical continuation changed directory or failed to advance')
    return HistoryPage(basis, namespace, entries, cursor)


@dataclass(frozen=True, slots=True)
class HistorySource:
    basis: HistoryBasis
    binding: HistoryEntry
    schema: Schema
    row_count: int
    changed_lsn: int
    authority: ReadAuthority


def _history_source(value: object, snapshot: HistoricalSnapshot, object_id: int) -> HistorySource:
    value = _object(value, 'snapshot binding schema rows changed_lsn authority')
    basis = _history_basis(value['snapshot'], snapshot); binding = _history_entry(value['binding']); schema = _schema(value['schema'])
    if binding.definition.interpretation.object.object_id != object_id or schema.object_id != object_id or binding.definition.interpretation.object.scope != basis.owner.scope or binding.definition.interpretation.object.branch != basis.branch: raise ValueError('Changed historical source object')
    return HistorySource(basis, binding, schema, _decimal(value['rows'], 0), _decimal(value['changed_lsn'], 0), _authority(value['authority']))


@dataclass(frozen=True, slots=True)
class ProjectionColumn:
    column: int
    physical: int | None
    initial_definition: Interpretation | None
    initial_state: str | None


@dataclass(frozen=True, slots=True)
class ProjectionDefinition:
    physical: StoredDefinition
    schema_revision: int
    rows: int
    columns: tuple[ProjectionColumn, ...]


@dataclass(frozen=True, slots=True)
class ProjectionLocation:
    origin: int
    operation: int
    ordinal: int
    physical: StoredDefinition
    schema_revision: int
    kind: str
    position: int
    offset: int
    content: Content | None
    row_bytes: int | None
    row_digest: bytes | None


@dataclass(frozen=True, slots=True)
class HistoryCoverageCursor(_Saved):
    @classmethod
    def restore(cls, saved: str) -> HistoryCoverageCursor: return cls(saved)
    def _validate(self, value: Any) -> None:
        value = _object(value, 'selector object kind source after')
        HistoricalSnapshot(value['selector']); _decimal(value['object']); _content(value['source'])
        if value['kind'] == 'definitions': _decimal(value['after'])
        elif value['kind'] == 'locations': _hex(value['after'], 20, True)
        else: raise ValueError('Invalid coverage kind')
    def _check(self, snapshot: HistoricalSnapshot, object_id: int, kind: str) -> object:
        value = self._wire()
        if value['selector'] != snapshot.selector or _decimal(value['object']) != object_id or value['kind'] != kind: raise ValueError('Coverage cursor belongs to a different selection')
        return value


@dataclass(frozen=True, slots=True)
class HistoryCoverage:
    basis: HistoryBasis
    logical: StoredDefinition
    accepted: Position
    total_rows: int
    definition: ProjectionDefinition | None
    locations: tuple[ProjectionLocation, ...]
    next: HistoryCoverageCursor | None


def _history_coverage(value: object, snapshot: HistoricalSnapshot, object_id: int, kind: str, previous: HistoryCoverageCursor | None) -> HistoryCoverage:
    value = _object(value, 'snapshot logical accepted total_rows definitions locations next')
    basis = _history_basis(value['snapshot'], snapshot); logical = _stored(value['logical'])
    if logical.interpretation.object.object_id != object_id or logical.interpretation.object.scope != basis.owner.scope or logical.interpretation.object.branch != basis.branch: raise ValueError('Changed coverage source')
    definition = None
    if value['definitions'] is not None:
        if kind != 'definitions': raise ValueError('Changed coverage kind')
        item = _object(value['definitions'], 'physical schema_revision rows columns')
        columns = []
        if not isinstance(item['columns'], list) or len(item['columns']) > 128: raise ValueError('Invalid coverage columns')
        for column in item['columns']:
            column = _object(column, 'column source'); source = column['source']
            if isinstance(source, dict) and set(source) == {'physical'}: columns.append(ProjectionColumn(_decimal(column['column']), _decimal(source['physical']), None, None))
            else:
                source = _object(_object(source, 'initial')['initial'], 'definition state')
                if source['state'] not in ('value', 'null', 'missing', 'type_error', 'conflict'): raise ValueError('Invalid initial state')
                columns.append(ProjectionColumn(_decimal(column['column']), None, _interpretation(source['definition']), source['state']))
        definition = ProjectionDefinition(_stored(item['physical']), _decimal(item['schema_revision']), _decimal(item['rows']), tuple(columns))
    if not isinstance(value['locations'], list) or len(value['locations']) > 8 or (kind != 'locations' and value['locations']): raise ValueError('Invalid coverage locations')
    locations = []
    for entry in value['locations']:
        entry = _object(entry, 'identity physical schema_revision location'); identity = _object(entry['identity'], 'origin operation ordinal')
        location = entry['location']; content = None; row_bytes = None; row_digest = None
        if isinstance(location, dict) and set(location) == {'segment'}:
            item = _object(location['segment'], 'id row content'); location_kind = 'segment'; position = _decimal(item['id']); offset = integer(item['row'], 'row', minimum=0, maximum=4294967295); content = _content(item['content'])
        else:
            item = _object(_object(location, 'wal')['wal'], 'lsn offset bytes row_digest'); location_kind = 'wal'; position = _decimal(item['lsn'], 0); offset = integer(item['offset'], 'offset', minimum=0, maximum=4294967295); row_bytes = integer(item['bytes'], 'bytes'); row_digest = _hex(item['row_digest'], 32, True)
        locations.append(ProjectionLocation(_decimal(identity['origin']), _decimal(identity['operation']), integer(identity['ordinal'], 'ordinal', minimum=0, maximum=4294967295), _stored(entry['physical']), _decimal(entry['schema_revision']), location_kind, position, offset, content, row_bytes, row_digest))
    cursor = None if value['next'] is None else HistoryCoverageCursor.restore(encode(value['next']).decode())
    if cursor:
        cursor._check(snapshot, object_id, kind)
        if previous and (cursor._wire()['source'] != previous._wire()['source'] or (int(cursor._wire()['after']) <= int(previous._wire()['after']) if kind == 'definitions' else cursor._wire()['after'] <= previous._wire()['after'])): raise ValueError('Coverage continuation failed to advance')
    return HistoryCoverage(basis, logical, _position(value['accepted']), _decimal(value['total_rows'], 0), definition, tuple(locations), cursor)
