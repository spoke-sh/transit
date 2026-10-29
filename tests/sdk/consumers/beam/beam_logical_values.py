"""Qualify recursive models through independent installed OTP artifacts."""

from sdk.artifact_versions import package_text
from runner.paths import ROOT
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile


def run(artifacts):
    root = ROOT
    with tempfile.TemporaryDirectory(prefix='transit-beam-logical-') as temporary:
        target = Path(temporary)
        library = target / 'lib'
        library.mkdir()
        identities = {}
        for package in ('transit_native_client', 'transit_client', 'transit_client_elixir', 'transit_native_station', 'transit_station_sdk', 'transit_station_elixir'):
            name = package_text(f'{package}-0.0.1.tar.gz', 'beam')
            source = Path(artifacts).resolve() / name
            identities[name] = hashlib.sha256(source.read_bytes()).hexdigest()
            with tarfile.open(source) as archive:
                archive.extractall(library, filter='data')
        (target / 'artifacts.json').write_text(json.dumps(identities))
        environment = {k: v for k, v in os.environ.items() if k not in ('ERL_LIBS', 'ERL_FLAGS', 'TRANSIT_LIBRARY_DIR', 'TRANSIT_HOST')}
        environment.update(ERL_LIBS=str(library), ERL_FLAGS='+S 2:2 +SDcpu 1 +SDio 1')
        classes = target / 'classes'
        classes.mkdir()
        for name in ('beam_schema_values.erl', 'beam_logical_values.erl', 'beam_handler_tables.erl'):
            source = target / name
            shutil.copy2(root / 'tests/sdk/consumers/beam' / name, source)
            subprocess.run(['erlc', '-Werror', '-o', str(classes), str(source)], env=environment, cwd=target, check=True)
            source.unlink()
        subprocess.run(['erl', '-noshell', '-pa', str(classes), '-s', 'beam_logical_values', 'main'], env=environment, cwd=target, check=True, timeout=45)
        subprocess.run(['erl', '-noshell', '-pa', str(classes), '-s', 'beam_handler_tables', 'main'], env=environment, cwd=target, check=True, timeout=45)
        elixir = target / 'consumer.exs'
        shutil.copy2(root / 'tests/sdk/consumers/elixir/elixir_logical_values.exs', elixir)
        subprocess.run(['elixir', str(elixir)], env=environment, cwd=target, check=True, timeout=45)
        shutil.copy2(root / 'tests/sdk/consumers/elixir/elixir_handler_tables.exs', elixir)
        subprocess.run(['elixir', str(elixir)], env=environment, cwd=target, check=True, timeout=45)
        print(json.dumps(dict(profile='installed-beam-logical-values', artifacts=identities)))


if __name__ == '__main__':
    run(*sys.argv[1:])
