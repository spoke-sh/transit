"""Compile clean OTP consumers and run both public Station authority schedules."""
from runner.paths import ROOT
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
from sdk.sdk_station_runner import Consumer, run as schedule
from sdk.sdk_http_runner import run as http_schedule


def run(node, cli, library, artifacts, http_worker=None, *, execute=None, languages=('erlang', 'elixir')):
    if execute is None and http_worker is None:
        raise ValueError("The full Station SDK schedule requires the HTTP worker binary")
    root = ROOT
    if not languages or any(language not in ('erlang', 'elixir') for language in languages):
        raise ValueError('Expected Erlang and/or Elixir')
    for language in languages:
        def install(target, language=language):
            lib = target / 'lib'
            lib.mkdir()
            names = ['transit_native_client', 'transit_client', 'transit_native_station', 'transit_station_sdk']
            if language == 'elixir': names += ['transit_client_elixir', 'transit_station_elixir']
            names.append(f'transit_sdk_examples_{language}')
            for name in names:
                with tarfile.open(Path(artifacts).resolve() / f'{name}-0.0.1.tar.gz') as archive:
                    archive.extractall(lib, filter='data')
            env = dict(os.environ, ERL_LIBS=str(lib), ERL_FLAGS='+S 2:2 +SDcpu 1 +SDio 1')
            classes = target / 'classes'
            classes.mkdir()
            sources = ['beam_station_controller.erl', 'beam_exchange_controller.erl', 'beam_document_controller.erl', 'beam_handler_tables.erl']
            if language == 'erlang': sources += ['beam_station_adapter.erl', 'beam_station_reentrant.erl', 'beam_http_adapter.erl', 'beam_grpc_adapter.erl', 'beam_document_adapter.erl']
            for name in sources:
                source = target / name
                shutil.copy2(root / 'tests/sdk/consumers/beam' / name, source)
                subprocess.run(['erlc', '-Werror', '-o', str(classes), str(source)], env=env, cwd=target, check=True)
                source.unlink()
            subprocess.run(['erl', '-noshell', '-pa', str(classes), '-s', 'beam_handler_tables', 'main'], env=env, cwd=target, check=True, timeout=45)
            if language == 'elixir':
                values = target / 'elixir_handler_tables.exs'
                shutil.copy2(root / 'tests/sdk/consumers/elixir/elixir_handler_tables.exs', values)
                subprocess.run(['elixir', str(values)], env=env, cwd=target, check=True, timeout=45)
                values.unlink()
                for name in ('elixir_station_adapter.ex', 'elixir_http_adapter.ex', 'elixir_grpc_adapter.ex', 'elixir_document_adapter.ex'):
                    source = target / name
                    shutil.copy2(root / 'tests/sdk/consumers/elixir' / source.name, source)
                    subprocess.run(['elixirc', '--warnings-as-errors', '-pa', str(classes), '-o', str(classes), str(source)], env=env, cwd=target, check=True)
                    source.unlink()
            fixtures = target / 'http-fixtures.json'
            http_data = json.loads((root / 'packages/zig/transit-station-http/src/admission-fixtures.json').read_bytes())
            http_data['released'] = json.loads((root / 'packages/zig/transit-station-http/src/release-fixtures.json').read_bytes())['reply']
            fixtures.write_text(json.dumps(http_data))
            grpc_fixtures = target / 'grpc-fixtures.json'
            shutil.copy2(root / 'packages/zig/transit-station-grpc/src/fixtures/service.json', grpc_fixtures)
            fake = target / 'bad-station-version'
            fake.write_text(f'#!{sys.executable}\nimport sys\nsys.stdin.readline()\nprint(\'{{"status":0,"value":{{"host_version":1,"station_version":99,"transit_version":1}}}}\')\n')
            fake.chmod(0o700)
            if language == 'erlang':
                incompatible = ['erl', '-noshell', '-eval', 'case transit_station_sdk:encode_cast(read, transit_example_counter_codec) of {error, E} when element(2, E) =:= incompatible_native -> halt(0); _ -> halt(1) end.']
            else:
                incompatible = ['elixir', '-e', '{:error, %Transit.Client.Error{kind: :incompatible_native}} = Transit.Station.Sdk.encode_cast(%Transit.SdkExamples.Read{}, Transit.SdkExamples.CounterCodec)']
            native = lib / 'transit_native_station-0.0.1'
            hidden = target / 'native.saved'
            native.rename(hidden)
            try: subprocess.run(incompatible, env=env, cwd=target, check=True, timeout=20)
            finally: hidden.rename(native)
            for app in ('transit_native_station', 'transit_client'):
                manifest = lib / f'{app}-0.0.1/ebin/{app}.app'
                original = manifest.read_text()
                manifest.write_text(original.replace('0.0.1', '99.0.0'))
                try: subprocess.run(incompatible, env=env, cwd=target, check=True, timeout=20)
                finally: manifest.write_text(original)
            def command(mode, config):
                if mode.startswith('document-'):
                    if language == 'erlang':
                        return ['erl', '-noshell', '-pa', str(classes), '-eval', 'beam_document_controller:main(beam_document_adapter, init:get_plain_arguments()), halt().', '-extra', mode, str(config)]
                    return ['elixir', '-pa', str(classes), '-e', ':beam_document_controller.main(ElixirDocumentAdapter, System.argv())', '--', mode, str(config)]
                if mode.startswith(('http-', 'grpc-')):
                    rpc = mode.startswith('grpc-')
                    selected = grpc_fixtures if rpc else fixtures
                    if language == 'erlang':
                        adapter = 'beam_grpc_adapter' if rpc else 'beam_http_adapter'
                        return ['erl', '-noshell', '-pa', str(classes), '-eval', f'beam_exchange_controller:main({adapter}, init:get_plain_arguments()), halt().', '-extra', mode, str(config), str(selected)]
                    adapter = 'ElixirGrpcAdapter' if rpc else 'ElixirHttpAdapter'
                    return ['elixir', '-pa', str(classes), '-e', f':beam_exchange_controller.main({adapter}, System.argv())', '--', mode, str(config), str(selected)]
                import json
                pending = Path(json.loads(config.read_text())['pending'])
                if not pending.exists():
                    with pending.open('xb') as file:
                        pending.chmod(0o600)
                        file.flush(); os.fsync(file.fileno())
                    fd = os.open(pending.parent, os.O_RDONLY | os.O_DIRECTORY)
                    try: os.fsync(fd)
                    finally: os.close(fd)
                if language == 'erlang': return ['erl', '-noshell', '-pa', str(classes), '-s', 'beam_station_controller', 'main', '-extra', mode, str(config)]
                return ['elixir', '-pa', str(classes), '-e', ':beam_station_controller.main(ElixirStationAdapter, System.argv())', '--', mode, str(config)]
            def example(config, role):
                if language == 'erlang': return ['erl', '-noshell', '-s', 'transit_erlang_counter', 'main', '-extra', str(config), role, '--commits', '1']
                return ['elixir', '-e', 'Transit.SdkExamples.CounterMain.main()', '--', str(config), role, '--commits', '1']
            return Consumer(env, command, example, 'invalid-handler', extra_failures=('exit-stop', 'exit-block'), arrow_adapter=False)
        (execute or schedule)(node, cli, library, install, language.capitalize())
        if execute is None: http_schedule(node, cli, library, http_worker, install, language.capitalize(), public_release=True, public_followup=True)


if __name__ == '__main__': run(*sys.argv[1:])
