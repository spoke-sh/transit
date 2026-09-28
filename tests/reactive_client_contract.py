"""Check reflected private host schemas and optionally validate an executed trace."""
import argparse
import json
from pathlib import Path
import subprocess
import jsonschema

parser = argparse.ArgumentParser()
parser.add_argument('exporter')
parser.add_argument('--trace', type=Path)
args = parser.parse_args()
path = Path('packages/zig/transit-serving/api/client.json')
actual = subprocess.check_output([str(Path(args.exporter).resolve()), 'client'])
assert actual == path.read_bytes(), f'{path}: regenerate the Zig-owned client contract'
schemas = json.loads(actual)
for schema in schemas.values():
    jsonschema.Draft202012Validator.check_schema(schema)
if args.trace:
    trace = json.loads(args.trace.read_text())
    for entry in trace:
        jsonschema.Draft202012Validator(schemas[entry['type']]).validate(entry['value'])
    print(f'Reactive private host contract: reflected drift and {len(trace)} actual request/response envelopes passed')
else:
    print('Reactive private host contract: reflected drift and schema validity passed')
