"""Validate complete SDK campaigns and summarize verified steady-state samples."""
import argparse
import json
import math
from pathlib import Path
import re
import statistics

from performance.sdk.workload import CASES, LANGUAGES


def integer(value, minimum=0):
    if type(value) is not int or value < minimum:
        raise ValueError('invalid count or timing')
    return value


def distribution(values):
    ordered = sorted(integer(value) for value in values)
    if not ordered:
        raise ValueError('missing samples')
    return dict(n=len(ordered), p50_ns=statistics.median(ordered),
                p95_ns=ordered[math.ceil(len(ordered) * .95) - 1], max_ns=ordered[-1])


def summarize(records):
    if not records or records[0].get('phase') != 'campaign' or records[0].get('outcome') != 'started':
        raise ValueError('missing campaign start')
    if records[-1] != dict(phase='campaign', outcome='complete'):
        raise ValueError('incomplete campaign')
    if sum(row.get('phase') == 'campaign' for row in records) != 2:
        raise ValueError('duplicate campaign')
    manifests = [row for row in records if row.get('phase') == 'manifest']
    if len(manifests) != 1 or manifests[0].get('version') != 1:
        raise ValueError('missing or foreign manifest')
    manifest, = manifests
    for key in ('definition', 'drivers', 'binaries', 'source', 'native_build', 'system',
                'machine', 'cpus', 'host_id', 'storage_device', 'toolchain', 'build_mode', 'storage_block_size',
                'rows', 'maintenance', 'durability', 'cache', 'completion', 'unsupported'):
        if key not in manifest:
            raise ValueError('missing manifest identity: ' + key)
    for key in ('drivers', 'binaries'):
        if not manifest[key] or any(not isinstance(value, str) or not re.fullmatch('[0-9a-f]{64}', value)
                                    for value in manifest[key].values()):
            raise ValueError('missing artifact digest')
    integer(manifest['rows'], 16)
    integer(manifest['cpus'], 1)
    if manifest['build_mode'] != 'ReleaseSafe' or manifest['native_build']['build']['optimize'] != 'safe':
        raise ValueError('unqualified build mode')
    languages = manifest['languages']
    if not languages or len(set(languages)) != len(languages) or set(languages) - set(LANGUAGES):
        raise ValueError('invalid languages')
    repeat, warmup = integer(manifest['repeat'], 1), integer(manifest['warmup'])
    if any(records[0].get(key) != manifest[key] for key in ('languages', 'repeat', 'warmup')):
        raise ValueError('changed campaign declaration')
    groups = {language: {} for language in languages}
    phases = {language: {} for language in languages}
    for row in records:
        phase = row['phase']
        if phase in ('campaign', 'manifest'):
            continue
        language = row.get('language')
        if language not in groups:
            raise ValueError('undeclared language')
        if phase != 'operation':
            if phase not in ('cold_start', 'client', 'resources', 'close', 'package_preparation') or phase in phases[language]:
                raise ValueError('duplicate or unknown phase')
            phases[language][phase] = row
            if phase in ('cold_start', 'close') and row.get('outcome') != 'complete':
                raise ValueError('failed consumer lifecycle')
            if phase == 'cold_start':
                if integer(row['first_verified_ns']) < integer(row['ready_ns']):
                    raise ValueError('invalid cold lifecycle timing')
            elif phase in ('close', 'package_preparation'):
                integer(row['elapsed_ns'])
            continue
        index = row.get('index')
        if type(index) is not int or not -warmup <= index < repeat or type(row.get('warmup')) is not bool or row['warmup'] != (index < 0):
            raise ValueError('invalid sample index')
        key = row.get('case'), index
        if key[0] not in CASES or key in groups[language]:
            raise ValueError('duplicate or unknown sample')
        if row.get('outcome') != 'complete' or row.get('consumer', {}).get('complete') is not True:
            raise ValueError('failed or incomplete sample')
        integer(row['elapsed_ns'])
        integer(row['consumer']['elapsed_ns'])
        groups[language][key] = row
    result = dict(manifest=manifest, qualification='exploratory single campaign; no numeric regression budget', languages={})
    for language in languages:
        expected = {(case, index) for case in CASES for index in range(-warmup, repeat)}
        if groups[language].keys() != expected:
            raise ValueError('missing workload samples')
        if phases[language].keys() != {'cold_start', 'client', 'resources', 'close', 'package_preparation'}:
            raise ValueError('missing consumer lifecycle or resources')
        result['languages'][language] = dict(lifecycle=phases[language], cases={
            case: dict(consumer=distribution([groups[language][case, index]['consumer']['elapsed_ns'] for index in range(repeat)]),
                       end_to_end=distribution([groups[language][case, index]['elapsed_ns'] for index in range(repeat)]))
            for case in CASES})
    return result


def compare(control, candidate):
    if any(not report['manifest'].get('native_provenance') for report in (control, candidate)):
        raise ValueError('native source provenance is required for comparison')
    for key in ('version', 'definition', 'drivers', 'system', 'machine', 'cpus', 'host_id', 'storage_device', 'toolchain',
                'build_mode', 'storage_block_size', 'maintenance', 'languages', 'rows', 'repeat', 'warmup',
                'durability', 'cache', 'completion', 'unsupported'):
        if control['manifest'].get(key) != candidate['manifest'].get(key):
            raise ValueError('incomparable campaigns: ' + key)
    for key in ('optimize', 'target', 'cpu', 'resolved_cpu', 'compiler'):
        if control['manifest']['native_build']['build'].get(key) != candidate['manifest']['native_build']['build'].get(key):
            raise ValueError('incomparable native builds: ' + key)
    ratios = {}
    for language, values in candidate['languages'].items():
        ratios[language] = {}
        for case, metrics in values['cases'].items():
            old = control['languages'][language]['cases'][case]['consumer']['p50_ns']
            new = metrics['consumer']['p50_ns']
            if new <= 0 or old <= 0:
                raise ValueError('nonpositive comparison timing')
            ratios[language][case] = old / new
    return ratios


def read(path):
    return summarize([json.loads(line) for line in Path(path).read_text().splitlines()])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('candidate', type=Path)
    parser.add_argument('--control', type=Path)
    args = parser.parse_args()
    result = read(args.candidate)
    if args.control:
        result['p50_speedup'] = compare(read(args.control), result)
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
