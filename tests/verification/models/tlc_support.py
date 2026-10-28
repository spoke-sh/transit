"""Shared fail-closed TLC record parsing, completion and Zig trace execution."""
import json
import re
import subprocess

from runner.paths import ROOT

def record(label, name, fields):
    match = re.search(r'/\\ ' + name + r' = \[(.*?)\](?:\n|$)', label, re.S)
    if not match:
        raise ValueError(f'missing {name} record')
    value = match[1]
    tokens = list(re.finditer(r'(\w+)\s*\|->\s*("[^"\\]*"|TRUE|FALSE|-?\d+)', value))
    remainder = re.sub(r'(\w+)\s*\|->\s*("[^"\\]*"|TRUE|FALSE|-?\d+)', '', value)
    if remainder.strip(' ,\n\t'):
        raise ValueError(f'unmapped {name} record: {value}')
    result = {m[1]: json.loads(m[2].lower() if m[2] in {'TRUE', 'FALSE'} else m[2]) for m in tokens}
    if set(result) != fields or len(tokens) != len(fields):
        raise ValueError(f'unmapped {name} fields: {result}')
    return result


def run_traces(binary, traces, destination, seconds):
    path = destination / 'replay.json'
    path.write_text(json.dumps(traces, separators=(',', ':')) + '\n')
    result = subprocess.run([binary, str(path)], cwd=ROOT, capture_output=True, text=True, timeout=seconds)
    if result.returncode:
        raise AssertionError(f'Zig replay failed: {result.stderr[-4000:]}')
    rows = [json.loads(line) for line in result.stdout.splitlines()]
    if len(rows) != len(traces):
        raise AssertionError('incomplete Zig replay')
    return rows


def complete(code, output):
    counts = re.search(r'([\d,]+) states generated, ([\d,]+) distinct states found, 0 states left on queue', output)
    if code != 0 or 'Model checking completed. No error has been found.' not in output or not counts:
        raise AssertionError(f'inconclusive/failed TLC exploration: {output[-4000:]}')
    return tuple(int(value.replace(',', '')) for value in counts.groups())
