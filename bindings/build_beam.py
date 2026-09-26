"""Build separate standard OTP applications without network dependency resolution."""
from pathlib import Path
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = '0.2.0'


def build(output, names):
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    environment = dict(os.environ, ERL_FLAGS='+S 2:2 +SDcpu 1 +SDio 1')
    with tempfile.TemporaryDirectory(prefix='transit-beam-build-') as temporary:
        base = Path(temporary)
        environment['ERL_LIBS'] = str(base)
        for name in names:
            source = ROOT / name if '/' in name else ROOT / 'packages/beam' / name
            app = source.name.replace('-', '_')
            target = base / f'{app}-{VERSION}'
            target.mkdir()
            ebin = target / 'ebin'
            ebin.mkdir()
            for directory in ('include', 'priv', 'docs'):
                if (source / directory).exists(): shutil.copytree(source / directory, target / directory)
            shutil.copy2(source / 'README.md', target / 'README.md')
            if name.startswith('transit-native-'):
                family = name.removeprefix('transit-native-')
                (target / 'priv').mkdir(exist_ok=True)
                shutil.copy2(ROOT / 'zig-out/bin' / f'transit-{family}-host', target / 'priv' / f'transit-{family}-host')
            erlang = sorted((source / 'src').glob('*.erl'))
            if erlang:
                subprocess.run(['erlc', '-Werror', '+debug_info', '-I', str(source / 'include'), '-o', str(ebin), *map(str, erlang)], env=environment, cwd=base, check=True)
            elixir = sorted((source / 'lib').glob('*.ex'))
            if elixir:
                assert f'version: "{VERSION}"' in (source / 'mix.exs').read_text()
                subprocess.run(['elixirc', '--warnings-as-errors', '-o', str(ebin), *map(str, elixir)], env=environment, cwd=base, check=True)
            modules = sorted(path.stem for path in ebin.glob('*.beam'))
            assert all(re.fullmatch(r'[A-Za-z0-9_.]+', module) for module in modules)
            module_list = '[' + ','.join("'" + module + "'" for module in modules) + ']'
            if elixir:
                dependencies = '[kernel,stdlib,elixir,transit_client]'
                manifest = f'{{application,{app},[{{description,"Transit Elixir public API"}},{{vsn,"{VERSION}"}},{{modules,{module_list}}},{{registered,[]}},{{applications,{dependencies}}}]}}.\n'
                shutil.copy2(source / 'mix.exs', target / 'mix.exs')
            else:
                manifest = (source / 'src' / f'{app}.app.src').read_text().replace('{modules, []}', '{modules, ' + module_list + '}')
                assert f'{{vsn, "{VERSION}"}}' in manifest
                shutil.copy2(source / 'rebar.config', target / 'rebar.config')
            (ebin / f'{app}.app').write_text(manifest)
            artifact = output / f'{app}-{VERSION}.tar.gz'
            with tarfile.open(artifact, 'w:gz') as archive: archive.add(target, arcname=target.name)
            print(f'Built {artifact.name}')


if __name__ == '__main__':
    build(sys.argv[1], sys.argv[2:] or ['transit-native-client', 'transit-client', 'transit-client-elixir'])
