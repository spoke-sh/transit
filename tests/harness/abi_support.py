"""Test-only ctypes driver for current generated C ABIs and exact saved bytes."""
from runner.paths import ROOT
import asyncio
import ctypes as c
import json
from pathlib import Path
import threading


class TransitError(Exception):
    def __init__(self, status, detail=None):
        self.status, self.detail = status, detail
        super().__init__(f"Transit status {status}: {detail}")


def _json(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode()


def _seed(path):
    data = bytes.fromhex(Path(path).read_text().strip())
    if len(data) != 32:
        raise ValueError("A private seed must contain exactly 32 bytes")
    return c.create_string_buffer(data, 32)


class _Library:
    def __init__(self, directory, family):
        self.family = family
        self.lib = c.CDLL(str(Path(directory).resolve() / f"libtransit_{family}.so"))
        contract = json.loads((ROOT / f"packages/zig/transit-{family}{'-bindings' if family == 'station' else ''}/abi-v1.json").read_text())
        def datatype(value, result=False):
            if value == "void":
                return None
            if value == "uint32_t":
                return c.c_uint32
            if value == "uint64_t":
                return c.c_uint64
            if value == "size_t":
                return c.c_size_t
            if value.endswith("**"):
                return c.POINTER(c.c_void_p)
            if value.endswith("*"):
                return c.c_void_p
            raise ValueError(f"Unsupported generated ABI type {value}")
        for function in contract["functions"]:
            native = getattr(self.lib, function["name"])
            native.argtypes = [datatype(t) for t in function["parameters"]]
            native.restype = datatype(function["result"], True)
        prefix = "station" if family == "station" else "transit"
        self.data = getattr(self.lib, f"{prefix}_buffer_data")
        self.size = getattr(self.lib, f"{prefix}_buffer_size")
        self.destroy = getattr(self.lib, f"{prefix}_buffer_destroy")
        version = self.lib.station_abi_version() if family == "station" else self.lib.transit_client_abi_version()
        if version != contract["version"]:
            raise TransitError(10, "ABI version mismatch")

    def take(self, pointer):
        if not pointer.value:
            return None
        try:
            return json.loads(c.string_at(self.data(pointer), self.size(pointer)))
        finally:
            self.destroy(pointer)

    def call(self, name, *args):
        result = c.c_void_p()
        status = getattr(self.lib, name)(*args, c.byref(result))
        value = self.take(result)
        if status:
            raise TransitError(status, value)
        return value


class _Owned:
    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()

    async def __aenter__(self):
        return self

    async def __aexit__(self, *_):
        await asyncio.to_thread(self.close)

    def _operation(self, fn, *args):
        if not self._lock.acquire(False):
            raise TransitError(9, "One operation per handle")
        try:
            if not self._handle.value:
                raise ValueError("Handle is closed")
            return fn(*args)
        finally:
            self._lock.release()

    def close(self):
        # An in-flight ctypes call retains this object and is deadline-bounded.
        with self._lock:
            if self._handle.value:
                self._destroy(self._handle)
                self._handle = c.c_void_p()

    def __del__(self):
        if hasattr(self, "_destroy"):
            self.close()


class Client(_Owned):
    def __init__(self, libraries, url, timeout_ms=5000):
        self._api = _Library(libraries, "client")
        self._lock, self._handle = threading.Lock(), c.c_void_p()
        endpoint = url.encode()
        status = self._api.lib.transit_client_create(1, c.create_string_buffer(endpoint), len(endpoint), timeout_ms, c.byref(self._handle))
        if status:
            raise TransitError(status)
        self._destroy = self._api.lib.transit_client_destroy

    def prepare(self, kind, seed_file, document):
        assert kind in (6, 7), "Only the current command/query ABI is supported"
        data, seed, operation = _json(document), _seed(seed_file), c.c_void_p()
        try:
            status = self._api.lib.transit_operation_prepare(kind, seed, c.create_string_buffer(data), len(data), c.byref(operation))
            if status:
                raise TransitError(status)
            pointer = c.c_void_p()
            status = self._api.lib.transit_operation_export(operation, c.byref(pointer))
            try:
                if status:
                    raise TransitError(status)
                return c.string_at(self._api.data(pointer), self._api.size(pointer)).decode()
            finally:
                self._api.destroy(pointer)
        finally:
            c.memset(seed, 0, 32)
            self._api.lib.transit_operation_destroy(operation)

    def call(self, frozen):
        data, operation = frozen.encode(), c.c_void_p()
        status = self._api.lib.transit_operation_import(c.create_string_buffer(data), len(data), c.byref(operation))
        if status:
            raise TransitError(status)
        try:
            return self._operation(self._api.call, "transit_client_call", self._handle, operation)
        finally:
            self._api.lib.transit_operation_destroy(operation)

    async def call_async(self, frozen):
        return await asyncio.to_thread(self.call, frozen)


def rejects(status, function, *args):
    try:
        function(*args)
    except TransitError as error:
        assert error.status == status, (error.status, error.detail)
        return error.detail
    raise AssertionError("Expected a native rejection")
