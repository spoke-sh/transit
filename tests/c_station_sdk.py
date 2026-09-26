"""Installed C callbacks/CLI and typed C++ runner share public authority proofs."""
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tarfile
from sdk_station_runner import Consumer, run as schedule


def run(node, cli, library, artifacts, *, execute=None):
    root = Path(__file__).resolve().parents[1]
    for language in ('C', 'C++'):
        def install(target, language=language):
            prefix = target / 'installed'
            for artifact in sorted(Path(artifacts).resolve().glob('*.tar.gz')):
                with tarfile.open(artifact) as archive: archive.extractall(prefix, filter='data')
            environment = {k: v for k, v in os.environ.items() if k not in ('LD_LIBRARY_PATH', 'LIBRARY_PATH', 'CPATH', 'CPLUS_INCLUDE_PATH', 'C_INCLUDE_PATH')}
            environment['PKG_CONFIG_PATH'] = str(prefix / 'lib/pkgconfig')
            flags = shlex.split(subprocess.check_output(['pkg-config', '--cflags', '--libs', 'transit-sdk-examples-cpp'], env=environment, text=True))
            source = target / 'consumer.cpp'; shutil.copyfile(root / 'tests/c_station_sdk.cpp', source)
            binary = target / 'consumer'
            subprocess.run(['zig', 'c++', '-std=c++17', '-Wall', '-Wextra', '-Werror', *(['-DTRANSIT_TEST_C_API'] if language == 'C' else []), source,
                            *flags, '-lpthread', '-o', binary], cwd=target, env=environment, check=True)
            source.unlink()
            if language == 'C++':
                for body in ('void wrong(transit::sdk::station::Turn &turn) { turn.state().put(transit::sdk::examples::total_key, true); }',
                             'void copy(transit::sdk::station::Runner<uint64_t> &runner) { auto copied = runner; }'):
                    source.write_text('#include <transit/sdk_examples.hpp>\n' + body)
                    result = subprocess.run(['zig', 'c++', '-std=c++17', '-fsyntax-only', source, f'-I{prefix / "include"}'], cwd=target, env=environment, capture_output=True, text=True)
                    assert result.returncode != 0 and ('conflicting types' in result.stderr or 'deleted' in result.stderr), result.stderr
                source.unlink()
            wrong = target / 'wrong-native'; wrong.mkdir()
            shutil.copy2(prefix / 'lib/libtransit_client.so', wrong / 'libtransit_client.so')
            contract = json.loads((root / 'packages/zig/transit-station/abi-v1.json').read_bytes())
            lines = ['#include <transit_station.h>']
            for function in contract['functions']:
                args = ', '.join(f'{kind} arg{i}' for i, kind in enumerate(function['parameters'])) or 'void'
                result = '' if function['result'] == 'void' else 'return 99;' if function['name'] == 'station_abi_version' else 'return 0;'
                lines.append(f'{function["result"]} {function["name"]}({args}) {{ {result} }}')
            fake = target / 'incompatible.c'; fake.write_text('\n'.join(lines))
            subprocess.run(['zig', 'cc', '-shared', '-fPIC', f'-I{prefix / "include"}', fake, '-o', wrong / 'libtransit_station.so'], cwd=target, env=environment, check=True)
            fake.unlink()
            fixtures = target / 'codecs.txt'
            data = json.loads((root / 'tests/verification/sdk-codecs-v1.json').read_bytes())
            fixtures.write_text(''.join(f'{category} {item["codec"]} {item["hex"] or "-"} {item["value"] if item["codec"] == "u64" and category == "valid" else "-"}\n'
                                       for category in ('valid', 'invalid') for item in data[category]))
            def command(mode, config):
                cfg = json.loads(config.read_bytes())
                assert cfg['profile'] == 'growing_v3'
                return [binary, mode, cfg['url'], str(cfg['realm']), str(cfg['principal']), str(cfg['pid']), str(cfg['generation']), cfg['seed_file'], str(cfg['peer']),
                        cfg['role'], str(cfg['resource']), cfg['pending'], cfg['output'], fixtures, '1' if cfg['query_results'] else '0', wrong]
            def installed_cli(config, role):
                cfg = json.loads(config.read_bytes())
                return [prefix / 'bin' / ('transit-c-counter' if language == 'C' else 'transit-cpp-counter'), cfg['url'], role, str(cfg['realm']), str(cfg['principal']), str(cfg['pid']),
                        str(cfg['generation']), cfg['seed_file'], str(cfg['peer']), '1', cfg['pending']]
            return Consumer(environment, command, installed_cli, 'invalid-thread', ('exception-stop', 'exception-block'), arrow_adapter=False)
        (execute or schedule)(node, cli, library, install, language)


if __name__ == '__main__': run(*sys.argv[1:])
