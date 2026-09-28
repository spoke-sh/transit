"""Pinned offline description validation and actual public wire trace checks."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import subprocess

import jsonschema
from referencing import Registry, Resource

ROOT = Path(__file__).resolve().parents[1]


def run(exporter, write=False, trace=None):
    directory = ROOT / 'tests/fixtures/reactive'
    pins = json.loads((directory / 'pins.json').read_text())
    registry = Registry()
    schemas = {}
    for name, pin in pins.items():
        raw = (directory / name).read_bytes()
        assert hashlib.sha256(raw).hexdigest() == pin['sha256'], name
        value = json.loads(raw)
        assert value['$id'] == pin['id']
        schemas[name] = value
        registry = registry.with_resource(pin['id'], Resource.from_contents(value))
    documents = {}
    for format in ('openapi', 'asyncapi'):
        raw = subprocess.check_output([str(Path(exporter).resolve()), format])
        document = json.loads(raw)
        official = schemas['openapi-3.2-base.json' if format == 'openapi' else 'asyncapi-3.0.json']
        validator = jsonschema.validators.validator_for(official)(official, registry=registry)
        validator.validate(document)
        for schema in document['components']['schemas'].values(): jsonschema.Draft202012Validator.check_schema(schema)
        target = ROOT / f'packages/zig/transit-serving/api/{format}.json'
        if write:
            target.parent.mkdir(exist_ok=True)
            target.write_bytes(raw)
        else:
            assert target.read_bytes() == raw, f'{format} generated description drift'
        documents[format] = document
    assert documents['openapi']['components']['schemas'] == documents['asyncapi']['components']['schemas']
    definitions = documents['openapi']['components']['schemas']
    def validate(name, value):
        schema = {'$ref': '#/components/schemas/' + name, 'components': {'schemas': definitions}}
        jsonschema.Draft202012Validator(schema).validate(value)
    fixture = json.loads((ROOT / 'packages/zig/transit-serving/src/fixtures/reactive-v1.json').read_text())
    validate('ReactiveRead', fixture['read'])
    invalid = copy.deepcopy(fixture['read']); invalid['read']['cursor']['position']['version'] = 2
    try: validate('ReactiveRead', invalid)
    except jsonschema.ValidationError: pass
    else: raise AssertionError('unsupported cursor version advertised')
    invalid = copy.deepcopy(fixture['read']); invalid['read']['unknown'] = True
    try: validate('ReactiveRead', invalid)
    except jsonschema.ValidationError: pass
    else: raise AssertionError('unknown envelope fields advertised')
    if trace:
        records = json.loads(Path(trace).read_text())
        assert len(records) >= 8
        for record in records: validate(record['type'], record['value'])
        print(f'Reactive descriptions: {len(records)} actual peer messages validated')
    print('Reactive descriptions: pinned OpenAPI 3.2.1/schema-base and AsyncAPI 3.0 validation, reflected schema parity, independent full-width fixtures and drift checks passed')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('exporter')
    parser.add_argument('--write', action='store_true')
    parser.add_argument('--trace')
    run(**vars(parser.parse_args()))
