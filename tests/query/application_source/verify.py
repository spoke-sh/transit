"""Strict independent grammar, AST, locations, formatter and product comparisons."""
import copy
import hashlib
import json
import importlib.metadata
import shutil
from pathlib import Path
import random
import sys
import tempfile
import threading

from runner import capture
from runner.paths import ROOT
from query.application_source import reference

SEED = 120440


def same(want, got, path='root'):
    assert type(want) is type(got), f'{path}: type {type(want).__name__} != {type(got).__name__}'
    if isinstance(want, dict):
        assert want.keys() == got.keys(), f'{path}: keys {want.keys()} != {got.keys()}'
        for key in want:
            same(want[key], got[key], f'{path}.{key}')
    elif isinstance(want, list):
        assert len(want) == len(got), f'{path}: length {len(want)} != {len(got)}'
        for index, (left, right) in enumerate(zip(want, got)):
            same(left, right, f'{path}.{index}')
    else:
        assert want == got, f'{path}: {want!r} != {got!r}'


def logical(value):
    """Only the declared source-coordinate fields differ after source formatting."""
    if isinstance(value, list):
        return [logical(item) for item in value]
    if isinstance(value, dict):
        return {key: logical(item) for key, item in value.items() if key not in ('span', 'start', 'end')}
    return value


def semantic_product(value):
    result = copy.deepcopy(value)
    del result['input_digest']
    def steps(items):
        for step in items:
            del step['definition']
            del step['call']
    steps(result['steps'])
    for case in result['cases']:
        del case['identity']
        del case['location']
        steps(case['steps'])
        for action in case['actions']:
            del action['location']
    return result


def at_path(value, path):
    for key in path.split('.'):
        value = value[int(key)] if isinstance(value, list) else value[key]
    return value


def cases():
    result = json.loads((ROOT / 'contracts/application-source/corpus.json').read_text())
    rng = random.Random(SEED)
    # Independent bounded construction exercises expressions, conditionals, lexical
    # variants and actual emitted schemas/plans, with a reproducible case identity.
    for index in range(32):
        n = rng.randrange(-10000, 10000)
        source = ("CREATE MODULE rows(n BIGINT) AS BEGIN IF (n + 2 * 3) >= 0 THEN "
                  "CREATE PUBLIC TABLE t (id BIGINT); INSERT INTO t VALUES ($n); ELSE "
                  "CREATE PUBLIC TABLE t (id BIGINT); INSERT INTO t VALUES ($n); END IF; END; "
                  f"CREATE TARGET default AS BEGIN USE rows({n}); SELECT * FROM t; END;")
        if index % 2:
            source = source.lower()
        if index % 3 == 0:
            source = source.replace(' ', '\r\n/* 雪 /* nested */ */ ')
        result.append({'name': f'generated-{SEED}-{index}', 'source': source, 'parse': True, 'compile': 'build', 'steps': 3})
    for count in (63, 64):
        result.append({'name': f'name-bound-{count}', 'source': f'CREATE MODULE {"n" * count}() AS BEGIN END;', 'parse': count == 63})
    for count in (64, 65):
        params = ', '.join(f'p{i} BIGINT' for i in range(count))
        result.append({'name': f'parameter-bound-{count}', 'source': f'CREATE MODULE m({params}) AS BEGIN END;', 'parse': count == 64})
        args = ', '.join(str(i) for i in range(count))
        result.append({'name': f'argument-bound-{count}', 'source': f'CREATE MODULE m() AS BEGIN USE f({args}); END;', 'parse': count == 64})
    return result


def command(argv, destination, label):
    result = {}
    stop = threading.Event()
    timer = threading.Timer(120, stop.set)
    timer.start()
    try:
        capture.run([str(x) for x in argv], cwd=ROOT, log=destination / f'{label}.log', result=result,
                    capture_stdout=True, cancelled=stop)
    finally:
        timer.cancel()
    capture.write_json(destination / f'{label}.json', result)
    assert result['completed'] and result['exit_code'] == 0 and not stop.is_set(), (label, result)
    output = destination / f'{label}.stdout'
    assert output.stat().st_size <= 16 * 1024 * 1024, f'{label}: output bound'
    return output.read_text()


def generate(destination):
    grammar = ROOT / 'contracts/application-source/TransitSource.g4'
    result = command(['antlr4', '-Dlanguage=Python3', '-visitor', '-Werror', '-lib', ROOT / 'contracts/sql',
                      '-Xexact-output-dir', '-o', destination / 'generated', grammar], destination, 'antlr')
    assert not result and not (destination / 'antlr.log').read_bytes(), 'ANTLR generation diagnostic'
    # Only generated ANTLR modules use this path; repository imports use launch.py.
    sys.path.insert(0, str(destination / 'generated'))


def execute(driver, rows, destination, label):
    path = destination / f'{label}-input.json'
    capture.write_json(path, rows)
    output = json.loads(command([driver, path], destination, label))
    assert [item['name'] for item in output] == [item['name'] for item in rows], 'missing/duplicate corpus records'
    return output


def provenance(case, got):
    """Check locations against this source version before removing coordinates."""
    sources = {'root/build.transit': case['source']}
    sources.update({f"{f.get('package', 'root')}/{f['path']}": f['text'] for f in case.get('files', [])})
    sites = {}
    for path, text in sources.items():
        positions = set()
        def walk(value):
            if isinstance(value, dict):
                if 'span' in value:
                    positions.add(value['span']['start'])
                for item in value.values():
                    walk(item)
            elif isinstance(value, list):
                for item in value:
                    walk(item)
        walk(reference.parse(text))
        sites[path] = positions
    def check(site):
        assert site['source'] in sources and site['offset'] in sites[site['source']], ('unattributed site', site)
        prefix = sources[site['source']].encode()[:site['offset']]
        same(prefix.count(b'\n') + 1, site['line'])
        same(len(prefix.rsplit(b'\n', 1)[-1]) + 1, site['column'])
    product = got['product']
    for step in product['steps'] + [s for c in product['cases'] for s in c['steps']]:
        check(step['definition'])
        if step['call']:
            check(step['call'])
    for item in product['cases']:
        check(item['location'])
        for action in item['actions']:
            check(action['location'])
    if 'step_sites' in case:
        same(len(case['step_sites']), len(product['steps']), 'attributed-step-count')
        for expected, step in zip(case['step_sites'], product['steps']):
            for key in ('definition', 'call'):
                site = expected[key]
                if site is None:
                    same(None, step[key])
                else:
                    source = sources[site['source']]
                    offset = len(source[:source.index(site['at'])].encode())
                    same(site['source'], step[key]['source'], 'attributed-source')
                    same(offset, step[key]['offset'], 'attributed-statement')
    # This fixture places its case directly in the selected test target. Compute
    # its identity independently from the documented length-prefixed components.
    if case['name'] == 'tests':
        digest = hashlib.sha256()
        digest.update(hashlib.sha256(b'tests').digest())
        for part in (b'root', b'build.transit', b'rows'):
            digest.update(len(part).to_bytes(8, 'little'))
            digest.update(part)
        same(digest.hexdigest(), product['cases'][0]['identity'], 'independent-case-identity')
    if case['name'] == 'imported-tests':
        def part(value):
            return len(value).to_bytes(8, 'little') + value
        calls = reference.parse(case['source'])['definitions'][0]['body']
        for call, item in zip(calls, product['cases']):
            expansion = hashlib.sha256(hashlib.sha256(b'tests').digest() + part(b'root') +
                                       part(b'build.transit') + call['span']['start'].to_bytes(8, 'little')).digest()
            identity = hashlib.sha256(expansion + part(b'root') + part(b'lib.transit') + part(b'roundtrip')).hexdigest()
            same(identity, item['identity'], 'independent-expanded-case-identity')


def controls(ast, product):
    tested = []
    def rejects(label, want, got):
        try:
            same(want, got)
        except AssertionError:
            tested.append(label)
        else:
            raise AssertionError(f'bad oracle passed: {label}')
    altered = copy.deepcopy(ast)
    altered['definitions'].pop()
    rejects('missing-definition', ast, altered)
    altered = copy.deepcopy(ast)
    sql = altered['definitions'][0]['body'][0]['value']['sql']
    sql['holes'][0]['role'] = 'value'
    rejects('wrong-hole-kind', ast, altered)
    altered = copy.deepcopy(ast)
    altered['definitions'][0]['body'][1]['value']['sql']['tokens'][-2]['text'] = "'different'"
    rejects('altered-literal', ast, altered)
    altered = copy.deepcopy(product)
    altered['cases'].pop()
    rejects('missing-case', product, altered)
    altered = copy.deepcopy(product)
    altered['cases'][0]['actions'].pop()
    rejects('missing-action', product, altered)
    altered = copy.deepcopy(product)
    altered['cases'][0]['actions'][2]['expected']['values'].append('00')
    rejects('extra-result', product, altered)
    return tested


def main():
    assert len(sys.argv) == 2, 'verify.py DRIVER'
    driver = Path(sys.argv[1]).resolve()
    parent = ROOT / '.cache/verification/application-source-grammar'
    parent.mkdir(parents=True, exist_ok=True)
    destination = Path(tempfile.mkdtemp(prefix='run-', dir=parent))
    inputs = cases()
    assert len({c['name'] for c in inputs}) == len(inputs)
    meta = {**capture.provenance(ROOT), 'seed': SEED, 'completed': False, 'driver': capture.identity(driver),
            'inputs': {str(path.relative_to(ROOT)): capture.identity(path) for path in [ROOT / 'contracts/application-source/TransitSource.g4', ROOT / 'contracts/sql/TransitExtensions.g4', ROOT / 'contracts/application-source/corpus.json']},
            'expected': [c['name'] for c in inputs]}
    meta['antlr_runtime'] = importlib.metadata.version('antlr4-python3-runtime')
    assert meta['antlr_runtime'] == '4.13.2'
    meta['antlr_tool'] = capture.identity(Path(shutil.which('antlr4')).resolve())
    capture.write_json(destination / 'evidence.json', meta)
    print(f'source grammar evidence: {destination}', flush=True)
    generate(destination)
    outputs = execute(driver, inputs, destination, 'original')
    file_inputs = [{'name': f"{case['name']}:{f['path']}", 'source': f['text']} for case in inputs for f in case.get('files', [])]
    file_outputs = execute(driver, file_inputs, destination, 'imported-files')
    formatted_files = {}
    for case, got in zip(file_inputs, file_outputs):
        same(reference.parse(case['source']), got['ast'], case['name'])
        same(logical(got['ast']), logical(reference.parse(got['formatted'])), case['name'] + '.format-reference')
        formatted_files[case['name']] = got['formatted']
    file_rounds = execute(driver, [{**case, 'source': got['formatted']} for case, got in zip(file_inputs, file_outputs)], destination, 'formatted-files')
    for before, after in zip(file_outputs, file_rounds):
        same(before['formatted'], after['formatted'], before['name'] + '.idempotence')
        same(logical(before['ast']), logical(after['ast']), before['name'] + '.roundtrip')
    round_inputs = []
    for case, got in zip(inputs, outputs):
        try:
            ast = reference.parse(case['source'])
        except reference.Refusal as error:
            assert not case['parse'], (case['name'], error)
            assert 'parse_error' in got, (case['name'], got)
            if 'parse_error' in case:
                same(case['parse_error'], got['parse_error'], case['name'] + '.refusal-category')
            if 'at' in case or case.get('at_eof'):
                offset = len(case['source'].encode()) if case.get('at_eof') else len(case['source'][:case['source'].index(case['at'])].encode())
                same(offset, error.offset, case['name'] + '.antlr-location')
                same(offset, got['location']['offset'], case['name'] + '.zig-location')
                prefix = case['source'].encode()[:offset]
                same(prefix.count(b'\n') + 1, got['location']['line'])
                same(len(prefix.rsplit(b'\n', 1)[-1]) + 1, got['location']['column'])
            continue
        assert case['parse'], case['name']
        same(ast, got.get('ast'), case['name'])
        if 'expected' in case:
            same(case['expected'], logical(ast), case['name'] + '.independent-expected')
        for path, value in case.get('checks', {}).items():
            same(value, at_path(ast, path), case['name'] + '.' + path)
        if 'error' in case:
            same(case['error'], got.get('compile_error'), case['name'] + '.stage')
        elif 'compile' in case:
            assert 'product' in got, (case['name'], got.get('compile_error'))
            provenance(case, got)
            if 'sql_expected' in case:
                same(case['sql_expected'], [step['sql'] for step in got['product']['steps']], case['name'] + '.independent-sql')
            if 'steps' in case:
                same(case['steps'], len(got['product']['steps']))
            if 'cases' in case:
                same(case['cases'], len(got['product']['cases']))
        same(logical(ast), logical(reference.parse(got['formatted'])), case['name'] + '.format-reference')
        round_inputs.append({**case, 'source': got['formatted'], 'files': [
            {**f, 'text': formatted_files[f"{case['name']}:{f['path']}"]} for f in case.get('files', [])]})
    rounded = execute(driver, round_inputs, destination, 'formatted')
    by_name = {item['name']: item for item in outputs}
    for case, got in zip(round_inputs, rounded):
        original = by_name[case['name']]
        same(logical(original['ast']), logical(got['ast']), case['name'] + '.roundtrip')
        same(original['formatted'], got['formatted'], case['name'] + '.idempotence')
        same(reference.parse(case['source']), got['ast'], case['name'] + '.formatted-locations')
        if 'product' in original:
            provenance(case, got)
            same(semantic_product(original['product']), semantic_product(got['product']), case['name'] + '.product')
        same(original.get('compile_error'), got.get('compile_error'), case['name'] + '.refusal')
    meta['negative_controls'] = controls(by_name['table-build']['ast'], by_name['tests']['product'])
    precedence = by_name['precedence']['ast']
    wrong = copy.deepcopy(precedence)
    wrong['definitions'][0]['body'][0]['value']['use']['arguments'][0]['value']['binary']['op'] = 'and_'
    try:
        same(precedence, wrong)
    except AssertionError:
        meta['negative_controls'].append('changed-precedence')
    else:
        raise AssertionError('precedence control passed')
    meta.update(completed=True, checked=len(outputs), roundtrips=len(rounded), imported_files=len(file_outputs))
    capture.write_json(destination / 'evidence.json', meta)
    print(f'PASS {len(outputs)} source cases, {len(rounded)} roundtrips, {len(meta["negative_controls"])} negative controls')


if __name__ == '__main__':
    main()
