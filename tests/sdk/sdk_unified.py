"""Installed consumers for the shared signed source/recovery schedule."""
from runner.paths import ROOT
import base64
import copy
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
import tomllib

import pyarrow
from unified_abi import Failure
from unified_codec import arrow_fixture, boolean_bundle_fixtures, nested_arrow_fixture, table_collation_fixtures



def compound_profile(state):
    return json.loads((state/'client.json').read_text()).get('compound', False)


def client_config(url, connection, state, kind):
    result = dict(url=url, connection=connection, seed_file=str(state/'caller.seed'), kind=kind,
        compound=compound_profile(state), bundle=str(state/'bundle.bin'))
    if kind == 'table':
        source = json.loads((state/'client.json').read_text())
        result.update(tables=source['tables'], capture=source['capture'])
    return result


class Consumer:
    def __init__(self, command, environment, directory, *, inspection=False, predicate_programs=False, compilation=False, read_timeout=90):
        self.read_timeout = read_timeout
        self.inspection = inspection
        self.predicate_programs = predicate_programs
        self.compilation = compilation
        self.child = subprocess.Popen(command, env=environment, cwd=directory,
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
        try: assert self.read() == {'ready': True}
        except BaseException:
            self.child.kill(); self.child.wait(timeout=10)
            self.child.stdin.close(); self.child.stdout.close()
            raise

    def read(self):
        assert select.select([self.child.stdout], [], [], self.read_timeout)[0], 'installed query caller timed out'
        line = self.child.stdout.readline()
        if not line:
            # EOF can race process reaping. Join before reporting the exit code;
            # the caller's finally block still kills a child that does not exit.
            code = self.child.wait(timeout=10)
            raise AssertionError(f'installed query caller exited ({code})')
        return json.loads(line)

    def send(self, action):
        self.child.stdin.write(json.dumps(action)+'\n'); self.child.stdin.flush()

    def call(self, action):
        self.send(action)
        result = self.read()
        if result['status']: raise Failure(result['status'], result['value'])
        return result['value']

    def close(self):
        try:
            if self.child.poll() is None:
                self.send({'close': {}})
                assert self.read() == {'closed': True}
                self.child.stdin.close()
                assert self.child.wait(timeout=10) == 0
        finally:
            if self.child.poll() is None: self.child.kill(); self.child.wait(timeout=10)
            self.child.stdin.close(); self.child.stdout.close()


def install(root, languages):
    root.mkdir()
    # The independent PyArrow fixture retains the production canonical schema.
    subprocess.run(['zig', 'build', 'logical-arrow-proof', '-Doptimize=ReleaseSafe', '--prefix', str(root/'producer')], cwd=ROOT, check=True)
    _, rows, _, ipc = arrow_fixture(str(root/'producer/bin/transit-logical-arrow-proof'))
    (root/'arrow.ipc').write_bytes(bytes.fromhex(ipc(rows)))
    (root/'empty.ipc').write_bytes(bytes.fromhex(ipc([])))
    bad = copy.deepcopy(rows); bad[0]['int64']['value'] = 1
    (root/'malformed.ipc').write_bytes(bytes.fromhex(ipc(bad)))
    shutil.copyfile(ROOT/'packages/zig/transit-query/src/fixtures/bundles.json', root/'bundles.json')
    fixtures = dict(bundles=str(root/'bundles.json'), arrow=str(root/'arrow.ipc'), empty=str(root/'empty.ipc'), malformed=str(root/'malformed.ipc'))
    (root/'boolean.json').write_text(json.dumps(boolean_bundle_fixtures()))
    fixtures['boolean'] = str(root/'boolean.json')
    (root/'collations.json').write_text(json.dumps(table_collation_fixtures()))
    fixtures['collations'] = str(root/'collations.json')
    nested_arrow_fixture(root/'producer/bin/transit-logical-arrow-proof', root/'nested.ipc')
    fixtures['nested'] = str(root/'nested.ipc')
    (root/'fixtures.json').write_text(json.dumps(fixtures))
    factories = []
    for language in languages:
        if language in ('erlang', 'elixir'):
            factories.append(install_beam(root / language, root / 'fixtures.json', language))
            continue
        if language == 'dotnet':
            factories.append(install_dotnet(root / language, root / 'fixtures.json'))
            continue
        if language == 'java':
            factories.append(install_java(root / language, root / 'fixtures.json'))
            continue
        if language in ('c', 'cpp'):
            factories.append(install_c(root / language, root, language))
            continue
        if language == 'rust':
            factories.append(install_rust(root / 'rust', root / 'fixtures.json'))
            continue
        if language == 'ruby':
            factories.append(install_ruby(root / 'ruby', root / 'fixtures.json'))
            continue
        if language == 'node':
            factories.append(install_node(root / 'node', root / 'fixtures.json'))
            continue
        if language != 'python': raise ValueError('Unsupported installed query SDK')
        env = {k: v for k, v in os.environ.items() if k not in ('PYTHONPATH', 'PYTHONHOME', 'TRANSIT_LIBRARY_DIR')}
        venv = root/'venv'
        subprocess.run([sys.executable, '-m', 'venv', '--without-pip', venv], check=True, env=env)
        python = str(venv/'bin/python')
        subprocess.run([sys.executable, '-m', 'pip', '--python', python, 'install', '--no-index',
            '--find-links', str(ROOT/'.cache/bindings/wheels'), 'transit-station==0.2.0'], check=True, env=env, stdout=subprocess.DEVNULL)
        script = root/'consumer.py'
        shutil.copyfile(ROOT/'tests/sdk/consumers/python/python_unified_sdk.py', script)
        subprocess.run([python, '-B', script, 'codecs', root/'fixtures.json'], check=True, env=env, cwd=root, timeout=90)
        def open_callers(url, connection, state, kind, python=python, script=script, env=env):
            config = root/'client.json'
            config.write_text(json.dumps(dict(client_config(url, connection, state, kind), arrow_site=str(Path(pyarrow.__file__).parent.parent))))
            first = Consumer([python, '-B', script, 'sync', config], env, root, inspection=True, predicate_programs=True, compilation=True)
            try: second = Consumer([python, '-B', script, 'async', config], env, root, inspection=True, predicate_programs=True, compilation=True)
            except BaseException:
                first.close()
                raise
            return [first, second]
        factories.append(open_callers)
    return factories


def install_python_direct(root, packages):
    root.mkdir()
    env = {k: v for k, v in os.environ.items() if k not in ('PYTHONPATH', 'PYTHONHOME', 'TRANSIT_LIBRARY_DIR')}
    venv = root/'venv'
    subprocess.run([sys.executable, '-m', 'venv', '--without-pip', venv], check=True, env=env)
    python = str(venv/'bin/python')
    subprocess.run([sys.executable, '-m', 'pip', '--python', python, 'install', '--no-index',
        '--find-links', str(packages), 'transit-station==0.2.0'], check=True, env=env, stdout=subprocess.DEVNULL)
    script = root/'consumer.py'; shutil.copyfile(ROOT/'tests/sdk/consumers/python/python_direct_capture.py', script)
    return lambda endpoint, profile, phase: subprocess.run([python, '-B', script, endpoint, str(profile), phase], cwd=root, env=env, check=True, timeout=120)


def install_node(root, fixtures, packages=ROOT/'.cache/bindings/node', *, direct=False):
    root.mkdir()
    dependencies = {f'@transit/{name}': 'file:' + str(packages/f'transit-{name}-0.2.0.tgz')
        for name in ('client', 'native-client', 'station', 'native-station')}
    manifest = dict(private=True, type='module', packageManager=json.loads((ROOT/'package.json').read_text())['packageManager'],
        dependencies={**dependencies, 'apache-arrow': '21.2.0'}, pnpm=dict(overrides=dependencies))
    (root/'package.json').write_text(json.dumps(manifest))
    env = {k: v for k, v in os.environ.items() if k not in ('NODE_PATH', 'TRANSIT_HOST', 'TRANSIT_LIBRARY_DIR')}
    subprocess.run(['vp', 'env', 'exec', '--package-manager', manifest['packageManager'], 'pnpm', 'install', '--prefer-offline', '--ignore-scripts'],
        cwd=root, env=env, check=True, stdout=subprocess.DEVNULL)
    script = root/'consumer.mjs'
    shutil.copyfile(ROOT/'tests/sdk/consumers/node'/('node_direct_capture.mjs' if direct else 'node_unified_sdk.mjs'), script)
    if direct:
        return lambda endpoint, profile, phase: subprocess.run(['node', script, endpoint, str(profile), phase], cwd=root, env=env, check=True, timeout=120)
    subprocess.run(['node', script, 'codecs', fixtures], cwd=root, env=env, check=True, timeout=90)
    def open_callers(url, connection, state, kind):
        config = root/'client.json'
        config.write_text(json.dumps(client_config(url, connection, state, kind)))
        return [Consumer(['node', script, 'serve', config], env, root, inspection=True, predicate_programs=True, compilation=True)]
    return open_callers


def install_ruby(root, fixtures, packages=ROOT/'.cache/bindings/ruby', *, direct=False):
    root.mkdir()
    default = subprocess.check_output(['ruby', '-rrubygems', '-e', 'puts Gem.default_dir'], text=True).strip()
    env = {k: v for k, v in os.environ.items() if k not in ('RUBYLIB', 'RUBYOPT', 'GEM_HOME', 'GEM_PATH', 'TRANSIT_HOST')}
    env.update(GEM_HOME=str(root/'gems'), GEM_PATH=f'{root / "gems"}:{default}')
    files = [packages/name for name in (
        'transit-native-client-0.2.0-x86_64-linux.gem', 'transit-client-0.2.0.gem',
        'transit-native-station-0.2.0-x86_64-linux.gem', 'transit-station-0.2.0.gem')]
    subprocess.run(['gem', 'install', '--local', '--no-document', '--ignore-dependencies', *files], env=env, cwd=root, check=True, stdout=subprocess.DEVNULL)
    script = root/'consumer.rb'
    shutil.copyfile(ROOT/'tests/sdk/consumers/ruby'/('ruby_direct_capture.rb' if direct else 'ruby_unified_sdk.rb'), script)
    if direct:
        return lambda endpoint, profile, phase: subprocess.run(['ruby', script, endpoint, str(profile), phase], cwd=root, env=env, check=True, timeout=120)
    subprocess.run(['ruby', script, 'codecs', fixtures], cwd=root, env=env, check=True, timeout=90)
    def open_callers(url, connection, state, kind):
        config = root/'client.json'
        config.write_text(json.dumps(client_config(url, connection, state, kind)))
        return [Consumer(['ruby', script, 'serve', config], env, root, inspection=True, predicate_programs=True, compilation=True)]
    return open_callers


def install_rust(root, fixtures, packages=ROOT/'.cache/bindings/rust', *, direct=False):
    root.mkdir()
    names = ('transit-client', 'transit-native-client', 'transit-station-sdk', 'transit-native-station')
    for name in names:
        with tarfile.open(packages/f'{name}-0.2.0.crate') as archive:
            archive.extractall(root/'vendor', filter='data')
    (root/'src').mkdir()
    shutil.copyfile(ROOT/'tests/sdk/consumers/rust'/('rust_direct_capture.rs' if direct else 'rust_unified_sdk.rs'), root/'src/main.rs')
    manifest = '''[package]
name = "transit-unified-proof"
version = "0.1.0"
edition = "2024"
[dependencies]
transit-client = "=0.2.0"
transit-station-sdk = { version = "=0.2.0", features = ["arrow"] }
serde_json = { version = "=1.0.145", features = ["arbitrary_precision"] }
[patch.crates-io]
'''
    manifest += ''.join(f'{name} = {{ path = "vendor/{name}-0.2.0" }}\n' for name in names)
    (root/'Cargo.toml').write_text(manifest)
    lock = root/'vendor/transit-station-sdk-0.2.0/Cargo.lock'
    shutil.copyfile(lock, root/'Cargo.lock')
    env = {k: v for k, v in os.environ.items() if k not in ('TRANSIT_LIBRARY_DIR', 'LD_LIBRARY_PATH', 'LIBRARY_PATH')}
    subprocess.run(['cargo', 'check', '--offline'], cwd=root, env=env, check=True)
    def registry(path):
        return {(p['name'], p['version'], p['checksum']) for p in tomllib.loads(path.read_text())['package'] if 'source' in p}
    assert registry(root/'Cargo.lock') == registry(lock)
    subprocess.run(['cargo', 'build', '--locked', '--offline'], cwd=root, env=env, check=True)
    executable = root/'consumer'
    shutil.copy2(root/'target/debug/transit-unified-proof', executable)
    if direct:
        def consume(endpoint, profile, phase):
            bundle = root/'bundle.bin'
            bundle.write_bytes(base64.b64decode(json.loads(profile.read_text())['captured']['bundle']['base64']))
            subprocess.run([executable, endpoint, str(profile), phase, str(bundle)], cwd=root, env=env, check=True, timeout=120)
        return consume
    subprocess.run([executable, 'codecs', fixtures], cwd=root, env=env, check=True, timeout=90)
    # One owned client cannot serve overlapping reads through shared borrows.
    (root/'src/main.rs').write_text('fn overlap(client: &mut transit_station_sdk::unified::Client) { let a = &mut *client; let b = &mut *client; a.status(1).unwrap(); b.status(1).unwrap(); } fn main() {}')
    rejected = subprocess.run(['cargo', 'check', '--locked', '--offline'], cwd=root, env=env, capture_output=True, text=True)
    assert rejected.returncode and 'cannot borrow `*client` as mutable more than once' in rejected.stderr
    shutil.rmtree(root/'vendor'); shutil.rmtree(root/'target'); shutil.rmtree(root/'src')
    def open_callers(url, connection, state, kind):
        config = root/'client.json'
        config.write_text(json.dumps(client_config(url, connection, state, kind)))
        return [Consumer([executable, 'serve', config], env, root, inspection=True, predicate_programs=True, compilation=True)]
    return open_callers


class CConsumer(Consumer):
    def send(self, action):
        if 'close' in action: command = 'close'
        elif 'submit' in action: command = 'submit ' + action['submit'].encode().hex()
        elif 'next' in action:
            v = action['next']; command = f"next {v['namespace']} {v['bundle']}"
        elif 'compile' in action:
            v = action['compile']; scope = v['scope']; limits = scope['limits']; parameters = v.get('parameters')
            command = f"compile {scope['name']} {v['sql'].encode().hex()} {limits['pages']} {limits['segments']} {limits['result_bytes']} {-1 if parameters is None else len(parameters)}"
            for item in parameters or ():
                kind, value = next(iter(item.items()))
                if kind == 'utf8': value = value.encode().hex()
                elif kind == 'boolean': value = 'true' if value else 'false'
                command += f' {kind}:{value}'
        elif 'inspect' in action:
            v = action['inspect']; scope = v['scope']; limits = scope['limits']
            command = f"inspect {scope['name']} {v['sql'].encode().hex()} {limits['pages']} {limits['segments']} {limits['result_bytes']}"
        elif 'page' in action:
            v = action['page']; command = f"page {v['namespace']} {v['cursor'].encode().hex() if v.get('cursor') is not None else '-'}"
        else:
            name, value = next(iter(action.items())); command = f'{name} {value}'
        self.child.stdin.write(command+'\n'); self.child.stdin.flush()

    def read(self):
        result = super().read()
        value = result.get('value', {})
        if 'prepared_hex' in value:
            encoded = value.pop('prepared_hex'); value['prepared'] = bytes.fromhex(encoded).decode() if encoded is not None else None
        if 'page' in value:
            encoded = value['page'].pop('next_hex'); value['page']['next'] = bytes.fromhex(encoded).decode() if encoded is not None else None
        return result


def install_c(root, fixtures, language, packages=ROOT / '.cache/bindings/c', *, direct=False):
    root.mkdir()
    prefix = root/'installed'
    for artifact in sorted(packages.glob('*.tar.gz')):
        with tarfile.open(artifact) as archive: archive.extractall(prefix, filter='data')
    env = {k: v for k, v in os.environ.items() if k not in ('TRANSIT_LIBRARY_DIR', 'LD_LIBRARY_PATH', 'LIBRARY_PATH', 'CPATH', 'CPLUS_INCLUDE_PATH', 'C_INCLUDE_PATH')}
    env['PKG_CONFIG_PATH'] = str(prefix/'lib/pkgconfig')
    flags = shlex.split(subprocess.check_output(['pkg-config', '--cflags', '--libs', 'transit-station-c' if language == 'c' else 'transit-station-cpp'], text=True, env=env))
    filename = 'c_unified_sdk.c' if language == 'c' else 'cpp_unified_sdk.cpp'
    if direct: filename = 'c_direct_capture.c' if language == 'c' else 'cpp_direct_capture.cpp'
    source = root/filename; shutil.copyfile(ROOT/'tests/sdk/consumers'/language/filename, source)
    shutil.copyfile(ROOT/'tests/sdk/unified_inspection_fixture.h', root/'unified_inspection_fixture.h')
    executable = root/'consumer'
    subprocess.run(['zig', 'cc' if language == 'c' else 'c++', '-std=c11' if language == 'c' else '-std=c++17', '-Wall', '-Wextra', '-Werror', source, *flags, '-lpthread', '-o', executable], cwd=root, env=env, check=True)
    source.unlink()
    if direct:
        def consume(endpoint, profile, phase):
            value = json.loads(profile.read_text())['captured']; route = value['connection']
            table = value['declaration']['source']['table']; capture = value['capture']
            seed = root/'capture.seed'; seed.write_text(('1d' if phase == 'prepare' else '3b') * 32); seed.chmod(0o600)
            bundle = root/'bundle.bin'; bundle.write_bytes(base64.b64decode(value['bundle']['base64']))
            args = [executable, phase, endpoint, str(seed), str(bundle)]
            args += [str(route[key]) for key in ('realm', 'principal', 'source', 'resource', 'requester', 'requests')]
            args += [str(table['scope']['resource']), str(table['scope']['catalog']), str(table['owner']), str(table['branch'])]
            args += [str(capture['executor']), str(capture['operation']), str(capture['expected']['partition']), str(capture['expected']['next_lsn'])]
            subprocess.run(args, cwd=root, env=env, check=True, timeout=120)
        return consume
    for i, item in enumerate(json.loads((fixtures/'bundles.json').read_text())):
        (fixtures/f'bundle{i}.bin').write_bytes(bytes.fromhex(item['wire_hex']))
        (fixtures/f'named-bundle{i}.bin').write_bytes(bytes.fromhex(item['named_wire_hex']))
        (fixtures/f'counted-bundle{i}.bin').write_bytes(bytes.fromhex(item['counted_wire_hex']))
    for i, item in enumerate(json.loads((fixtures/'boolean.json').read_text())):
        (fixtures/f'boolean{i}.bin').write_bytes(bytes.fromhex(item['wire_hex']))
    for i, item in enumerate(json.loads((fixtures/'collations.json').read_text())):
        (fixtures/f'collation{i}.bin').write_bytes(bytes.fromhex(item['wire_hex']))
    subprocess.run([executable, 'codecs', fixtures], cwd=root, env=env, check=True, timeout=90)
    if language == 'cpp':
        source.write_text('#include <transit/unified_query.hpp>\nvoid copy(transit::sdk::station::unified::Client &client) { auto other = client; }')
        rejected = subprocess.run(['zig', 'c++', '-std=c++17', '-fsyntax-only', source, f'-I{prefix / "include"}'], cwd=root, env=env, capture_output=True, text=True)
        assert rejected.returncode and 'deleted' in rejected.stderr
        source.unlink()
    def open_callers(url, connection, state, kind):
        arguments = [executable, 'serve', url, str(state/'caller.seed'), kind, str(state/'bundle.bin')]
        arguments += [str(connection[key]) for key in ('realm', 'principal', 'source', 'resource', 'requester', 'requests')]
        arguments.append('compound' if compound_profile(state) else 'atom')
        if kind == 'table':
            config = client_config(url, connection, state, kind); t = config['tables']; c = config['capture']
            arguments += [t['url'], str(t['connection']['scope']['resource']), str(t['connection']['scope']['catalog']),
                str(t['connection']['branch']), str(t['connection']['audience']), str(c['executor']), str(c['operation']),
                str(c['expected']['partition']), str(c['expected']['next_lsn'])]
        return [CConsumer(arguments, env, root, inspection=True, predicate_programs=True, compilation=True)]
    return open_callers


def install_java(root, fixtures, packages=ROOT/'.cache/bindings/java', *, direct=False):
    root.mkdir(); lib = root/'lib'; lib.mkdir()
    names = ('transit-client', 'transit-native-client', 'transit-station-sdk', 'transit-native-station')
    for name in (*[f'{name}-0.2.0.jar' for name in names], 'gson-2.12.1.jar'):
        shutil.copy2(packages/name, lib/name)
    env = {k: v for k, v in os.environ.items() if k not in ('CLASSPATH', 'JAVA_TOOL_OPTIONS', '_JAVA_OPTIONS', 'JDK_JAVA_OPTIONS', 'TRANSIT_HOST')}
    name = 'JavaDirectCapture' if direct else 'JavaUnifiedSdk'
    source = root/f'{name}.java'; shutil.copyfile(ROOT/'tests/sdk/consumers/java'/source.name, source)
    classes = root/'classes'; classes.mkdir()
    subprocess.run(['javac', '--release', '21', '-Xlint:all', '-Werror', '-cp', str(lib/'*'), '-d', classes, source], cwd=root, env=env, check=True)
    source.unlink()
    command = ['java', f'-Djava.io.tmpdir={root}', '-cp', os.pathsep.join([str(classes), str(lib/'*')]), name]
    if direct:
        return lambda endpoint, profile, phase: subprocess.run([*command, endpoint, str(profile), phase], cwd=root, env=env, check=True, timeout=120)
    subprocess.run([*command, 'codecs', fixtures], cwd=root, env=env, check=True, timeout=90)
    def open_callers(url, connection, state, kind):
        config = root/'client.json'
        config.write_text(json.dumps(client_config(url, connection, state, kind)))
        return [Consumer([*command, 'serve', config], env, root, inspection=True, predicate_programs=True, compilation=True)]
    return open_callers


def install_dotnet(root, fixtures, packages=ROOT/'.cache/bindings/dotnet', *, direct=False):
    import xml.etree.ElementTree as ET
    root.mkdir(); source = root/'source'; source.mkdir(); feed = root/'feed'; feed.mkdir()
    for package in ('Transit.Client', 'Transit.Native.Client', 'Transit.Station.Sdk', 'Transit.Native.Station'):
        name = f'{package}.0.2.0.nupkg'; shutil.copy2(packages/name, feed/name)
    env = {k: v for k, v in os.environ.items() if k not in ('TRANSIT_LIBRARY_DIR', 'LD_LIBRARY_PATH', 'LIBRARY_PATH')}
    env.update(NUGET_PACKAGES=str(root/'packages'), DOTNET_CLI_TELEMETRY_OPTOUT='1', DOTNET_NOLOGO='1')
    project = source/'Consumer.csproj'
    project.write_text('''<Project Sdk="Microsoft.NET.Sdk">
<PropertyGroup><TargetFramework>net8.0</TargetFramework><OutputType>Exe</OutputType><ImplicitUsings>enable</ImplicitUsings><Nullable>enable</Nullable><TreatWarningsAsErrors>true</TreatWarningsAsErrors></PropertyGroup>
<ItemGroup><PackageReference Include="Transit.Client" Version="[0.2.0]" /><PackageReference Include="Transit.Station.Sdk" Version="[0.2.0]" /></ItemGroup>
</Project>''')
    config = ET.Element('configuration'); sources = ET.SubElement(config, 'packageSources'); ET.SubElement(sources, 'clear')
    ET.SubElement(sources, 'add', key='local-built', value=str(feed)); ET.ElementTree(config).write(source/'NuGet.Config', encoding='utf-8', xml_declaration=True)
    shutil.copyfile(ROOT/'tests/sdk/consumers/dotnet'/('DotnetDirectCapture.cs' if direct else 'DotnetUnifiedSdk.cs'), source/'Program.cs')
    subprocess.run(['dotnet', 'restore', project.name, '--configfile', 'NuGet.Config'], cwd=source, env=env, check=True)
    app = root/'app'
    subprocess.run(['dotnet', 'build', project.name, '--no-restore', '-c', 'Release', '-o', app], cwd=source, env=env, check=True)
    shutil.rmtree(source); shutil.rmtree(root/'packages')
    command = ['dotnet', str(app/'Consumer.dll')]
    if direct:
        return lambda endpoint, profile, phase: subprocess.run([*command, endpoint, str(profile), phase], cwd=root, env=env, check=True, timeout=120)
    subprocess.run([*command, 'codecs', fixtures], cwd=root, env=env, check=True, timeout=90)
    def open_callers(url, connection, state, kind):
        config = root/'client.json'
        config.write_text(json.dumps(client_config(url, connection, state, kind)))
        return [Consumer([*command, 'serve', config], env, root, inspection=True, predicate_programs=True, compilation=True)]
    return open_callers


def install_beam(root, fixtures, language, packages=ROOT / '.cache/bindings/beam', *, direct=False):
    root.mkdir(); lib = root/'lib'; lib.mkdir(); classes = root/'classes'; classes.mkdir()
    names = ['transit_native_client', 'transit_client', 'transit_native_station', 'transit_station_sdk']
    if language == 'elixir': names += ['transit_client_elixir', 'transit_station_elixir']
    for name in names:
        with tarfile.open(packages/f'{name}-0.2.0.tar.gz') as archive: archive.extractall(lib, filter='data')
    env = {k: v for k, v in os.environ.items() if k not in ('ERL_LIBS', 'ERL_FLAGS', 'TRANSIT_HOST')}
    env.update(ERL_LIBS=str(lib), ERL_FLAGS='+S 2:2 +SDcpu 1 +SDio 1')
    controller = 'beam_direct_capture' if direct else 'beam_unified_controller'
    sources = [f'{controller}.erl'] + (['beam_unified_adapter.erl'] if language == 'erlang' else [])
    for name in sources:
        source = root/name; shutil.copyfile(ROOT/'tests/sdk/consumers/beam'/name, source)
        subprocess.run(['erlc', '-Werror', '-o', classes, source], cwd=root, env=env, check=True); source.unlink()
    if language == 'elixir':
        source = root/'elixir_unified_adapter.ex'; shutil.copyfile(ROOT/'tests/sdk/consumers/elixir'/source.name, source)
        subprocess.run(['elixirc', '--warnings-as-errors', '-pa', classes, '-o', classes, source], cwd=root, env=env, check=True); source.unlink()
        command = ['elixir', '-pa', str(classes), '-e', f':{controller}.main(ElixirUnifiedAdapter, System.argv())', '--']
    else:
        command = ['erl', '-noshell', '-pa', str(classes), '-eval', f'{controller}:main(beam_unified_adapter, init:get_plain_arguments()), halt().', '-extra']
    if direct:
        return lambda endpoint, profile, phase: subprocess.run([*command, endpoint, str(profile), phase], cwd=root, env=env, check=True, timeout=120)
    subprocess.run([*command, 'codecs', fixtures], cwd=root, env=env, check=True, timeout=90)
    def open_callers(url, connection, state, kind):
        config = root/'client.json'
        config.write_text(json.dumps(client_config(url, connection, state, kind)))
        return [Consumer([*command, 'serve', config], env, root, inspection=True, predicate_programs=True, compilation=True)]
    return open_callers


if __name__ == '__main__':
    if sys.argv[1:]:
        raise SystemExit('Usage: python3 -B tests/runner/launch.py tests/sdk/sdk_unified.py (build SDK packages first)')
    languages = ('python', 'node', 'ruby', 'rust', 'c', 'cpp', 'java', 'dotnet', 'erlang', 'elixir')
    with tempfile.TemporaryDirectory(prefix='transit-sdk-codecs-') as directory:
        install(Path(directory) / 'installed', languages)
    print('All ten installed query SDK codec consumers passed, including four independently encoded Table collation vectors; no authority or recovery claim.')
