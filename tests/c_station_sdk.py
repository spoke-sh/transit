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
from sdk_http_runner import run as http_schedule


def run(node, cli, library, artifacts, http_worker=None, *, execute=None):
    if execute is None and http_worker is None:
        raise ValueError("The full Station SDK schedule requires the HTTP worker binary")
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
            http_binary = target / 'http-consumer'
            http_sources = [target / name for name in ('c_http_sdk.cpp', 'c_http_sdk.c', 'c_http_sdk.h')]
            for item in http_sources: shutil.copyfile(root / 'tests' / item.name, item)
            http_object = target / 'http-callbacks.o'
            subprocess.run(['zig', 'cc', '-std=c11', '-Wall', '-Wextra', '-Werror', f'-I{prefix / "include"}', '-c', http_sources[1], '-o', http_object],
                           cwd=target, env=environment, check=True)
            subprocess.run(['zig', 'c++', '-std=c++17', '-Wall', '-Wextra', '-Werror', *(['-DTRANSIT_TEST_C_API'] if language == 'C' else []),
                            http_sources[0], http_object, *flags, '-lpthread', '-o', http_binary], cwd=target, env=environment, check=True)
            for item in [*http_sources, http_object]: item.unlink()
            if language == 'C++':
                for body in ('void wrong(transit::sdk::station::Turn &turn) { turn.state().put(transit::sdk::examples::total_key, true); }',
                             'void copy(transit::sdk::station::Runner<uint64_t> &runner) { auto copied = runner; }'):
                    source.write_text('#include <transit/sdk_examples.hpp>\n' + body)
                    result = subprocess.run(['zig', 'c++', '-std=c++17', '-fsyntax-only', source, f'-I{prefix / "include"}'], cwd=target, env=environment, capture_output=True, text=True)
                    assert result.returncode != 0 and ('conflicting types' in result.stderr or 'deleted' in result.stderr), result.stderr
                source.unlink()
                # The secondary public runner header is self-contained too.
                source.write_text('#include <transit/station/runner.hpp>\n')
                header_object = target / 'header.o'
                subprocess.run(['zig', 'c++', '-std=c++17', '-c', source, f'-I{prefix / "include"}', '-o', header_object], cwd=target, env=environment, check=True)
                header_object.unlink()
                source.unlink()
            wrong = target / 'wrong-native'; wrong.mkdir()
            shutil.copy2(prefix / 'lib/libtransit_client.so', wrong / 'libtransit_client.so')
            contract = json.loads((root / 'packages/zig/transit-station-bindings/abi-v1.json').read_bytes())
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
            http_fixtures = target / 'http-codecs.txt'
            data = json.loads((root / 'packages/zig/transit-station-http/src/admission-fixtures.json').read_bytes())
            release = json.loads((root / 'packages/zig/transit-station-http/src/release-fixtures.json').read_bytes())
            http_fixtures.write_text('\n'.join([data['body'], data['reference'], data['metadata'].encode().hex(), data['outcome'], data['rejection'], release['reply']]) + '\n')
            def command(mode, config):
                cfg = json.loads(config.read_bytes())
                assert cfg['profile'] == 'growing_v3'
                if mode.startswith('http-'):
                    return [http_binary, mode, cfg['url'], str(cfg['principal']), str(cfg['pid']), str(cfg['generation']), cfg['seed_file'], str(cfg['peer']),
                            str(cfg['resource']), cfg['body'], str(cfg['deadline']), cfg.get('outcome', ''), cfg.get('ready', ''), cfg.get('continue', ''), cfg.get('accepted', ''), http_fixtures]
                return [binary, mode, cfg['url'], str(cfg['realm']), str(cfg['principal']), str(cfg['pid']), str(cfg['generation']), cfg['seed_file'], str(cfg['peer']),
                        cfg['role'], str(cfg['resource']), cfg['pending'], cfg['output'], fixtures, '1' if cfg['query_results'] else '0', wrong]
            def installed_cli(config, role):
                cfg = json.loads(config.read_bytes())
                return [prefix / 'bin' / ('transit-c-counter' if language == 'C' else 'transit-cpp-counter'), cfg['url'], role, str(cfg['realm']), str(cfg['principal']), str(cfg['pid']),
                        str(cfg['generation']), cfg['seed_file'], str(cfg['peer']), '1', cfg['pending']]
            return Consumer(environment, command, installed_cli, 'invalid-thread', ('exception-stop', 'exception-block'), arrow_adapter=False)
        (execute or schedule)(node, cli, library, install, language)
        if execute is None: http_schedule(node, cli, library, http_worker, install, language, public_release=True)


if __name__ == '__main__': run(*sys.argv[1:])
