"""Independent consumption of standard gRPC binary metadata, never message scraping."""
from runner.paths import ROOT
import json
from pathlib import Path
import pyarrow.flight as flight

HEADER = 'transit-diagnostic-bin'
DEFINITION = json.loads((ROOT/'contracts/diagnostic-v1.schema.json').read_bytes())['properties']['definition']['enum'][0]


def decode(encoded):
    assert isinstance(encoded, bytes) and 0 < len(encoded) <= 4096, encoded
    value = json.loads(encoded)
    assert value['definition'] == DEFINITION and value['version'] == 1, value
    assert len(value['facts']) == 16 and len(value['actions']) == 4, value
    return value


class Details(flight.ClientMiddlewareFactory):
    def __init__(self):
        self.headers = {}

    def start_call(self, info):
        self.headers = {}
        return _Call(self)

    def diagnostic(self):
        values = self.headers.get(HEADER, [])
        assert len(values) == 1, self.headers
        return decode(values[0])


class _Call(flight.ClientMiddleware):
    def __init__(self, owner):
        self.owner = owner

    def received_headers(self, headers):
        for key, values in headers.items():
            self.owner.headers.setdefault(key, []).extend(values)


def adbc_diagnostic(error):
    values = [value for key,value in error.details if key == HEADER.encode()]
    assert len(values) == 1, error.details
    return decode(values[0])
