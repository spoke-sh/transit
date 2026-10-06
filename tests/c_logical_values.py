"""Qualify C11/C++17 logical models from independently installed artifacts."""
import hashlib
import json
import os
from pathlib import Path
import select
import shlex
import shutil
import subprocess
import sys
import tarfile
import tempfile
from fuze_logical_arrow import recursive_cases
from fuze_types import fixtures


def oracle(binary, target, environment):
    child = subprocess.Popen([binary, 'codec'], cwd=target, env=environment, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    count = 0
    def check(kind, value):
        nonlocal count
        child.stdin.write(kind + json.dumps(value, ensure_ascii=True) + '\n')
        child.stdin.flush()
        assert select.select([child.stdout], [], [], 30)[0], 'installed C codec timed out'
        raw = child.stdout.readline()
        assert raw and raw != 'invalid\n', (kind, raw)
        assert json.loads(raw) == value
        count += 1
    try:
        for case in fixtures()['cases']:
            kind = case['kind']
            desc = bytes.fromhex(case['type_hex'])
            raw = bytes.fromhex(case['value_hex'])[8 + len(desc):]
            params = {'precision': desc[-2], 'scale': desc[-1]} if kind == 'decimal' else 'utc' if kind == 'timestamp' else {}
            check('t', {kind: params})
            if kind.startswith(('int', 'uint')):
                atom = {'signed' if kind.startswith('int') else 'unsigned': case['literal']}
            elif kind.startswith('float'):
                atom = {'float_bits': raw.hex()}
            elif kind == 'decimal':
                atom = {'decimal': str(int.from_bytes(raw, 'little', signed=True))}
            elif kind == 'boolean':
                atom = {'boolean': case['literal'] == 'true'}
            elif kind == 'utf8':
                atom = {'utf8': case['literal']}
            elif kind == 'date':
                atom = {'date_days': str(int.from_bytes(raw, 'little', signed=True))}
            elif kind == 'time':
                atom = {'time_nanos': str(int.from_bytes(raw, 'little'))}
            elif kind == 'timestamp':
                atom = {'timestamp_micros': str(int.from_bytes(raw, 'little', signed=True))}
            elif kind == 'uuid':
                atom = {'uuid': raw.hex()}
            else:
                raise AssertionError(kind)
            check('c', {'value': {'atom': atom}})
        for typ, cell in recursive_cases():
            check('t', typ)
            for value in (cell, {'missing': {}}, {'null': {}}, {'type_error': 'utf8'}, {'conflict': [
                {'counter': '9007199254740993', 'replica': '18446744073709551615', 'value': cell},
                {'counter': '18446744073709551615', 'replica': '1', 'value': {'null': {}}}]}):
                check('c', value)
        child.stdin.close()
        assert child.wait(timeout=10) == 0
    finally:
        if child.poll() is None:
            child.kill()
            child.wait(timeout=10)
        child.stdin.close()
        child.stdout.close()
    return count


def run(artifacts):
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix='transit-c-logical-') as temporary:
        target = Path(temporary)
        prefix = target / 'installed'
        identities = {}
        for package in ('transit-native-client-c', 'transit-client-c', 'transit-client-cpp', 'transit-native-station-c', 'transit-station-c', 'transit-station-cpp'):
            name = package + '-0.2.0' + ('' if package.endswith('-cpp') else '-linux-x86_64') + '.tar.gz'
            source = Path(artifacts).resolve() / name
            identities[name] = hashlib.sha256(source.read_bytes()).hexdigest()
            with tarfile.open(source) as archive:
                archive.extractall(prefix, filter='data')
        (target / 'artifacts.json').write_text(json.dumps(identities))
        environment = {k: v for k, v in os.environ.items() if k not in ('TRANSIT_LIBRARY_DIR', 'LD_LIBRARY_PATH', 'LIBRARY_PATH', 'CPATH', 'CPLUS_INCLUDE_PATH', 'C_INCLUDE_PATH')}
        environment['PKG_CONFIG_PATH'] = str(prefix / 'lib/pkgconfig')
        binaries = {}
        for language, extension, compiler, standard in [('c', 'c', 'cc', 'c11'), ('cpp', 'cpp', 'c++', 'c++17')]:
            source = target / f'consumer.{extension}'
            shutil.copy2(root / 'tests' / f'{language}_logical_values.{extension}', source)
            flags = shlex.split(subprocess.check_output(['pkg-config', '--cflags', '--libs', 'transit-station-' + language], env=environment, text=True))
            binary = target / language
            subprocess.run(['zig', compiler, '-std=' + standard, '-Wall', '-Wextra', '-Werror', str(source), *flags, '-o', str(binary)], env=environment, cwd=target, check=True)
            source.unlink()
            subprocess.run([binary], cwd=target, env=environment, check=True, timeout=90)
            binaries[language] = binary
        count = oracle(binaries['c'], target, environment)
        print(json.dumps(dict(profile='installed-c-cpp-logical-values', fixtures=count, artifacts=identities)))


if __name__ == '__main__':
    run(*sys.argv[1:])
