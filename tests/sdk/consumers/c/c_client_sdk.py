"""Installed C/C++ clients share authority scenarios, independently of Station."""
from runner.paths import ROOT
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tarfile
from sdk.sdk_raw_client import run as schedule


def run(node, cli, library, artifacts):
    root = ROOT
    artifacts = Path(artifacts).resolve()
    for language, source, compiler in [('C', 'c_client_sdk.c', 'cc'), ('C++', 'cpp_client_sdk.cpp', 'c++')]:
        def install(target):
            prefix = target / 'installed'
            packages = ['transit-native-client-c-0.0.1-linux-x86_64', 'transit-client-c-0.0.1-linux-x86_64']
            if language == 'C++': packages.append('transit-client-cpp-0.0.1')
            for package in packages:
                with tarfile.open(artifacts / f'{package}.tar.gz') as archive: archive.extractall(prefix, filter='data')
            environment = {k: v for k, v in os.environ.items() if k not in ('LD_LIBRARY_PATH', 'LIBRARY_PATH', 'CPATH', 'CPLUS_INCLUDE_PATH', 'C_INCLUDE_PATH')}
            environment['PKG_CONFIG_PATH'] = str(prefix / 'lib/pkgconfig')
            package = 'transit-client-cpp' if language == 'C++' else 'transit-client-c'
            flags = shlex.split(subprocess.check_output(['pkg-config', '--cflags', '--libs', package], env=environment, text=True))
            shutil.copyfile(root / 'tests/sdk/consumers' / ('c' if language == 'C' else 'cpp') / source, target / source)
            binary = target / 'consumer'
            subprocess.run(['zig', compiler, '-std=c++17' if language == 'C++' else '-std=c11', '-Wall', '-Wextra', '-Werror',
                            str(target / source), *flags, '-lpthread', '-o', binary], env=environment, cwd=target, check=True)
            (target / source).unlink()
            # A consumer compiled with a foreign C SDK definition must fail
            # before calling into an ABI with differently sized public structs.
            foreign = target / 'foreign-definition.c'
            foreign.write_text('extern void transit_sdk_growing_config_' + '0'*64 + '(void);\nint main(void) { transit_sdk_growing_config_' + '0'*64 + '(); return 0; }\n')
            rejected = subprocess.run(['zig', 'cc', foreign, *flags, '-o', target / 'foreign-consumer'], env=environment, cwd=target, capture_output=True)
            assert rejected.returncode != 0 and b'transit_sdk_growing_config_' in rejected.stderr, rejected.stderr
            foreign.unlink()
            # Every reflected export exists; only the ABI version is incompatible.
            wrong = target / 'wrong-native'; wrong.mkdir()
            contract = json.loads((root / 'packages/zig/transit-client/abi-v1.json').read_bytes())
            lines = ['#include <transit_client.h>']
            for function in contract['functions']:
                args = ', '.join(f'{kind} arg{i}' for i, kind in enumerate(function['parameters'])) or 'void'
                result = '' if function['result'] == 'void' else 'return 99;' if function['name'] == 'transit_client_abi_version' else 'return 0;'
                lines.append(f'{function["result"]} {function["name"]}({args}) {{ {result} }}')
            fake = target / 'incompatible.c'; fake.write_text('\n'.join(lines))
            subprocess.run(['zig', 'cc', '-shared', '-fPIC', f'-I{prefix / "include"}', fake, '-o', wrong / 'libtransit_client.so'], env=environment, cwd=target, check=True)
            fake.unlink()
            assert not (prefix / 'lib/libtransit_station.so').exists()
            if language == 'C':
                lifetime = target / 'native-lifetime'
                source_path = target / 'c_native_lifetime.c'
                shutil.copyfile(root / 'tests/sdk/consumers/c/c_native_lifetime.c', source_path)
                subprocess.run(['zig', 'cc', '-std=c11', '-Wall', '-Wextra', '-Werror', source_path,
                                *flags, '-lpthread', '-ldl', '-o', lifetime], env=environment, cwd=target, check=True)
                source_path.unlink()
                images = target / 'images'
                for index in range(16):
                    directory = images / str(index); directory.mkdir(parents=True)
                    shutil.copyfile(wrong / 'libtransit_client.so', directory / 'libtransit_client.so')
                subprocess.run([lifetime, prefix / 'lib', images], env=environment, cwd=target, check=True, timeout=30)
            def invoke(mode, config):
                value = json.loads(Path(config).read_bytes())
                return subprocess.check_output([binary, mode, value['url'], value['seed'], str(value['pid']), value['pending'], value['spawn'], value['accepted'], wrong], env=environment, cwd=target, timeout=30)
            return invoke
        schedule(node, cli, library, install, language)


if __name__ == '__main__': run(*sys.argv[1:])
