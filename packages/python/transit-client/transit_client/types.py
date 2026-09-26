"""Validated public values; references confer no authority."""
from __future__ import annotations
from dataclasses import dataclass, field
import json
from pathlib import Path
import re

_CONTRACT = json.loads((Path(__file__).parent / 'client-abi.json').read_bytes())
MAX_COUNTER: int = _CONTRACT['limits']['max_counter']
VALUE_BYTES: int = _CONTRACT['limits']['value_bytes']
MAX_BODY: int = _CONTRACT['limits']['max_body']


def owned_bytes(value: object, limit: int) -> bytes:
    if not isinstance(value, (bytes, bytearray, memoryview)):
        raise TypeError('Expected bytes, bytearray or memoryview')
    length = value.nbytes if isinstance(value, memoryview) else len(value)
    if length > limit:
        raise ValueError(f'Byte value exceeds the {limit}-byte operation bound')
    return bytes(value)


def integer(value: object, name: str, *, minimum: int = 1, maximum: int = MAX_COUNTER) -> int:
    if type(value) is not int or not minimum <= value <= maximum:
        raise ValueError(f"{name} must be an integer in [{minimum}, {maximum}]")
    return value


@dataclass(frozen=True, slots=True)
class ProcessRef:
    realm: int
    pid: int
    def __post_init__(self) -> None:
        integer(self.realm, 'realm')
        integer(self.pid, 'pid')


@dataclass(frozen=True, slots=True)
class ResourceRef:
    realm: int
    resource: int
    def __post_init__(self) -> None:
        integer(self.realm, 'realm')
        integer(self.resource, 'resource')


@dataclass(frozen=True, slots=True)
class Credential:
    realm: int
    principal: int
    seed_file: Path = field(repr=False)
    def __post_init__(self) -> None:
        integer(self.realm, 'realm')
        integer(self.principal, 'principal', minimum=0)
        object.__setattr__(self, 'seed_file', Path(self.seed_file))


@dataclass(frozen=True, slots=True)
class OperationIdentity:
    sha256: str
    def __post_init__(self) -> None:
        if not isinstance(self.sha256, str) or re.fullmatch('[0-9a-f]{64}', self.sha256) is None:
            raise ValueError('Invalid native operation identity')


@dataclass(frozen=True, slots=True)
class AdmissionReceipt:
    position: int
    def __post_init__(self) -> None:
        integer(self.position, 'receipt position')


@dataclass(frozen=True, slots=True)
class MutationReceipt:
    position: int
    def __post_init__(self) -> None:
        integer(self.position, 'receipt position')


@dataclass(frozen=True, slots=True)
class ClientConfig:
    url: str
    profile: str
    timeout_ms: int = 5000
    native_directory: Path | None = field(default=None, repr=False)
    def __post_init__(self) -> None:
        if self.profile != 'growing_v3':
            raise ValueError('The public client requires explicit growing_v3; legacy operations use the raw binding')
        if not isinstance(self.url, str):
            raise TypeError('url must be text')
        if len(self.url) > MAX_BODY or len(self.url.encode()) > MAX_BODY:
            raise ValueError('url exceeds the native request bound')
        integer(self.timeout_ms, 'timeout_ms', maximum=60000)
        if self.native_directory is not None:
            object.__setattr__(self, 'native_directory', Path(self.native_directory))


@dataclass(frozen=True, slots=True)
class Capabilities:
    realm: int
    observed_at: int
    principal_sequence: int
    page_size: int
    mutations_per_turn: int
    outputs_per_turn: int
    retained_versions: bool
    station: bool
    def __post_init__(self) -> None:
        integer(self.realm, 'realm')
        integer(self.observed_at, 'observed_at', minimum=0)
        integer(self.principal_sequence, 'principal_sequence', minimum=0)
        for name in ('page_size', 'mutations_per_turn', 'outputs_per_turn'):
            integer(getattr(self, name), name)
        if type(self.retained_versions) is not bool or type(self.station) is not bool:
            raise TypeError('Capability flags must be booleans')
