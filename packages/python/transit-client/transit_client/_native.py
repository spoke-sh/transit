"""Generated ABI loader and owned byte transfer, shared by Python SDK packages."""
from __future__ import annotations
import ctypes as c
import json
import importlib
from pathlib import Path
from typing import Any
from .errors import IncompatibleNative, native_error


def encode(value: object) -> bytes:
    return json.dumps(value, ensure_ascii=False, separators=(',', ':')).encode()


def seed(path: Path) -> c.Array[c.c_char]:
    # Bound credential reads too. Never put credential text into an exception.
    with path.open('rb') as source:
        value = source.read(129).strip()
    if len(value) != 64:
        raise ValueError('A seed file must contain 64 hexadecimal characters')
    try:
        result = bytes.fromhex(value.decode('ascii'))
    except (ValueError, UnicodeError):
        raise ValueError('Invalid seed encoding') from None
    if len(result) != 32:
        raise ValueError('Invalid seed size')
    return c.create_string_buffer(result, 32)


class Library:
    def __init__(self, family: str, contract_path: Path, directory: Path | None) -> None:
        self.contract: dict[str, Any] = json.loads(contract_path.read_bytes())
        if directory is None:
            try:
                artifact = importlib.import_module('transit_native_' + family)
                path = artifact.library_path()
            except (ImportError, OSError, RuntimeError):
                raise IncompatibleNative('Install matching native artifacts or set native_directory') from None
        else:
            path = directory.resolve() / f'libtransit_{family}.so'
        try:
            self.lib = c.CDLL(str(path))
            for entry in self.contract['functions']:
                function = getattr(self.lib, entry['name'])
                function.argtypes = [self._type(item) for item in entry['parameters']]
                function.restype = self._type(entry['result'])
            prefix = 'transit' if family == 'client' else 'station'
            version = getattr(self.lib, 'transit_client_abi_version' if family == 'client' else 'station_abi_version')()
            if version != self.contract['version']:
                raise ValueError('ABI version')
            definition = self.contract['definition'].encode('ascii')
            compatible = getattr(self.lib, 'transit_client_abi_definition_matches' if family == 'client' else 'station_abi_definition_matches')
            if compatible(definition, len(definition)) != 1:
                raise ValueError('ABI definition')
            self.data = getattr(self.lib, prefix + '_buffer_data')
            self.size = getattr(self.lib, prefix + '_buffer_size')
            self.destroy = getattr(self.lib, prefix + '_buffer_destroy')
        except (OSError, AttributeError, ValueError):
            raise IncompatibleNative(f'Missing or incompatible {family} native artifact; install its matching transit-native-{family} 0.2.0') from None

    @staticmethod
    def _type(value: str) -> Any:
        if value == 'void': return None
        if value == 'uint32_t': return c.c_uint32
        if value == 'uint64_t': return c.c_uint64
        if value == 'size_t': return c.c_size_t
        if value.endswith('**'): return c.POINTER(c.c_void_p)
        if value.endswith('*'): return c.c_void_p
        raise IncompatibleNative('Unknown generated ABI type')

    def take(self, buffer: c.c_void_p) -> bytes | None:
        if not buffer.value:
            return None
        try:
            return c.string_at(self.data(buffer), self.size(buffer))
        finally:
            self.destroy(buffer)

    def call_bytes(self, name: str, *args: object, recovery: bytes = b'') -> bytes | None:
        pointer = c.c_void_p()
        status = getattr(self.lib, name)(*args, c.byref(pointer))
        value = self.take(pointer)
        if status:
            raise native_error(status, json.loads(value) if value else None, phase=name, recovery=recovery)
        return value

    def call(self, name: str, *args: object, recovery: bytes = b'') -> Any:
        value = self.call_bytes(name, *args, recovery=recovery)
        return json.loads(value) if value is not None else None
