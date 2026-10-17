"""Build separate standard OTP applications without network dependency resolution."""
from pathlib import Path
import argparse
import os
import re
import shutil
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = '0.2.0'
MIX_MANIFEST = '''Mix.start()
Code.require_file(hd(System.argv()))
project = Mix.Project.config()
application = Mix.Project.get!().application()
deps = Enum.map(Keyword.get(project, :deps, []), &elem(&1, 0))
apps = Enum.uniq([:kernel, :stdlib, :elixir] ++ Keyword.get(application, :extra_applications, []) ++ deps)
term = {:application, project[:app], [description: ~c"Transit Elixir public API", vsn: String.to_charlist(project[:version]), modules: [], registered: [], applications: apps]}
IO.write(:io_lib.format(~c"~tp.~n", [term]))
'''


def build(output, names, native_prefix=None):
    output = Path(output).resolve()
    native_prefix = Path(native_prefix).resolve() if native_prefix else ROOT / 'zig-out'
    output.mkdir(parents=True, exist_ok=True)
    environment = dict(os.environ, ERL_FLAGS='+S 2:2 +SDcpu 1 +SDio 1')
    with tempfile.TemporaryDirectory(prefix='transit-beam-build-') as temporary:
        base = Path(temporary)
        environment['ERL_LIBS'] = str(base)
        for name in names:
            source = ROOT / name if '/' in name else ROOT / 'sdks/beam' / name
            erlang = sorted((source / 'src').glob('*.erl'))
            elixir = sorted((source / 'lib').glob('*.ex'))
            if elixir:
                assert f'version: "{VERSION}"' in (source / 'mix.exs').read_text()
                # Dependency ownership comes from the actual Mix project.
                manifest = subprocess.check_output(['elixir', '-e', MIX_MANIFEST, str(source / 'mix.exs')], env=environment, cwd=base, text=True)
                app = re.search(r'\{application,\s*([a-z0-9_]+),', manifest).group(1)
            else:
                source_manifest, = (source / 'src').glob('*.app.src')
                app = source_manifest.name.removesuffix('.app.src')
                manifest = source_manifest.read_text()
                assert f'{{vsn, "{VERSION}"}}' in manifest
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
                shutil.copy2(native_prefix / 'bin' / f'transit-{family}-host', target / 'priv' / f'transit-{family}-host')
            if erlang:
                subprocess.run(['erlc', '-Werror', '+debug_info', '-pa', str(ebin), '-I', str(source / 'include'), '-o', str(ebin), *map(str, erlang)], env=environment, cwd=base, check=True)
            if elixir:
                subprocess.run(['elixirc', '--warnings-as-errors', '-o', str(ebin), *map(str, elixir)], env=environment, cwd=base, check=True)
            modules = sorted(path.stem for path in ebin.glob('*.beam'))
            assert all(re.fullmatch(r'[A-Za-z0-9_.]+', module) for module in modules)
            module_list = '[' + ','.join("'" + module + "'" for module in modules) + ']'
            manifest = re.sub(r'\{modules,\s*\[\]\}', '{modules,' + module_list + '}', manifest)
            for file in ('mix.exs', 'rebar.config'):
                if (source / file).exists(): shutil.copy2(source / file, target / file)
            (ebin / f'{app}.app').write_text(manifest)
            artifact = output / f'{app}-{VERSION}.tar.gz'
            with tarfile.open(artifact, 'w:gz') as archive: archive.add(target, arcname=target.name)
            print(f'Built {artifact.name}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output')
    parser.add_argument('names', nargs='*')
    parser.add_argument('--native-prefix')
    args = parser.parse_args()
    build(args.output, args.names or ['transit-native-client', 'transit-client', 'transit-client-elixir', 'transit-native-station', 'transit-station-sdk', 'transit-station-elixir',
                                      'examples/station-sdk/erlang', 'examples/station-sdk/elixir'], args.native_prefix)
