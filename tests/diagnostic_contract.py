#!/usr/bin/env python3
"""Reject drift between the public diagnostic types and committed schema."""
import json
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
actual = json.load(sys.stdin)
expected = json.loads((root / 'contracts/diagnostic-v1.schema.json').read_text())
assert actual == expected, 'Diagnostic schema drift: run just contract::generate after reviewing the contract.'
required = actual['required']
assert 'definition' in required and 'version' in required
properties = actual['properties']
assert properties['facts']['minItems'] == properties['facts']['maxItems'] == 16
assert properties['actions']['minItems'] == properties['actions']['maxItems'] == 4
assert actual['additionalProperties'] is False
assert properties['code']['maxLength'] == 96
print('Diagnostic v1: generated shape, mandatory definition and bounded context/action collections agree.')
