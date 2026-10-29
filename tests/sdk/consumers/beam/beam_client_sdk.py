"""Install independent OTP artifacts and run both public language schedules."""

from sdk.artifact_versions import package_text
from runner.paths import ROOT
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
from sdk.sdk_raw_client import run as schedule


def run(node, cli, library, artifacts):
    root = ROOT
    for language in ('erlang', 'elixir'):
        def install(target):
            lib = target / 'lib'
            lib.mkdir()
            names = ['transit_native_client', 'transit_client']
            if language == 'elixir': names.append('transit_client_elixir')
            for name in names:
                with tarfile.open(Path(artifacts).resolve() / package_text(f'{name}-0.0.1.tar.gz', 'beam')) as archive:
                    archive.extractall(lib, filter='data')
            environment = dict(os.environ, ERL_LIBS=str(lib), ERL_FLAGS='+S 2:2 +SDcpu 1 +SDio 1')
            for name, output in {
                'bad-version': b'{"status":0,"value":{"host_version":99,"transit_version":1}}\n',
                'fraction': b'{"status":0,"value":{"host_version":1.00000000000000000001,"transit_version":1}}\n',
                'duplicate': b'{"status":0,"value":{"host_version":1,"host_version":1,"transit_version":1}}\n',
                'oversized': b'x' * 540673, 'partial': b'{', 'invalid-utf8': b'\xff\n',
                'invalid-status': b'{"status":99,"value":null}\n',
            }.items():
                fake = target / name
                fake.write_text(f'#!{sys.executable}\nimport sys\nsys.stdin.readline()\nsys.stdout.buffer.write({output!r})\nsys.stdout.buffer.flush()\n')
                fake.chmod(0o700)
            if language == 'erlang':
                source = target / 'beam_client_sdk.erl'
                shutil.copy2(root / 'tests/sdk/consumers/beam/beam_client_sdk.erl', source)
                classes = target / 'classes'
                classes.mkdir()
                boundary = target / 'beam_client_boundary.erl'
                shutil.copy2(root / 'tests/sdk/consumers/beam/beam_client_boundary.erl', boundary)
                subprocess.run(['erlc', '-Werror', '-o', str(classes), str(boundary)], env=environment, cwd=target, check=True)
                boundary.unlink()
                schema = target / 'beam_schema_values.erl'
                shutil.copy2(root / 'tests/sdk/consumers/beam/beam_schema_values.erl', schema)
                subprocess.run(['erlc', '-Werror', '-o', str(classes), str(schema)], env=environment, cwd=target, check=True)
                schema.unlink()
                check_command = ['erl', '-noshell', '-pa', str(classes), '-s', 'beam_client_boundary', 'main', '-extra', str(target)]
                native = lib / package_text('transit_native_client-0.0.1', 'beam')
                hidden = target / 'native.saved'
                native.rename(hidden)
                try: subprocess.run([*check_command, 'missing'], env=environment, cwd=target, check=True, timeout=20)
                finally: hidden.rename(native)
                manifest = native / 'ebin/transit_native_client.app'
                original = manifest.read_text()
                manifest.write_text(original.replace(package_text('0.0.1', 'beam'), '99.0.0'))
                try: subprocess.run([*check_command, 'missing'], env=environment, cwd=target, check=True, timeout=20)
                finally: manifest.write_text(original)
                subprocess.run([*check_command, 'normal'], env=environment, cwd=target, check=True, timeout=30)
                subprocess.run(['erlc', '-Werror', '+debug_info', '-o', str(classes), str(source)], env=environment, cwd=target, check=True)
                source.unlink()
                command = ['erl', '-noshell', '-pa', str(classes), '-s', 'beam_client_sdk', 'main', '-extra']
            else:
                manifest = lib / package_text('transit_client-0.0.1/ebin/transit_client.app', 'beam')
                original = manifest.read_text()
                manifest.write_text(original.replace(package_text('0.0.1', 'beam'), '99.0.0'))
                try:
                    subprocess.run(['elixir', '-e', '{:ok, c} = Transit.Client.config("http://127.0.0.1:1", :native_v1); '
                                    '{:error, %Transit.Client.Error{kind: :incompatible_native}} = Transit.Client.open(c)'],
                                   env=environment, cwd=target, check=True, timeout=20)
                finally: manifest.write_text(original)
                source = target / 'consumer.exs'
                shutil.copy2(root / 'tests/sdk/consumers/elixir/elixir_client_sdk.exs', source)
                command = ['elixir', str(source)]
            def invoke(mode, config):
                return subprocess.check_output([*command, mode, str(config)], env=environment, cwd=target, timeout=80)
            return invoke
        schedule(node, cli, library, install, language.capitalize())


if __name__ == '__main__': run(*sys.argv[1:])
