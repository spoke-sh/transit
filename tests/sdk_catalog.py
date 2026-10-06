"""Install catalog SDK packages in isolated consumer environments."""
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tarfile
import tomllib
import zipfile
from sdk_unified import Consumer

ROOT = Path(__file__).resolve().parents[1]


def install(root, languages):
    root.mkdir()
    # Matching, independently generated neutral evidence for decoder ownership
    # tests. The authority schedules below verify live owner projections.
    definition = json.loads((ROOT / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition']
    identity = dict(domain='mutation', id=str(2**64-1), realm='46', resource='7', sequence=None)
    def fact(field, origin, kind, value):
        return dict(field=field, origin=origin, availability='provided', value={kind: value})
    diagnostic = dict(version=1, definition=definition, code='table.applied', category='lifecycle',
        stage='execute', outcome='applied', evidence='domain_status',
        message='The original Table operation completed. Later inspection or output failures cannot undo its outcome.',
        cause=None, identity=identity, location=None,
        facts=[fact('object', 'owner', 'unsigned', str(2**64-1)),
               fact('operation', 'caller', 'text', 'insert'),
               fact('native_input', 'owner', 'unsigned', '7'),
               fact('affected_rows', 'execution', 'unsigned', '1')] + [None]*12,
        actions=[dict(kind='inspect_status', target=identity)] + [None]*3)
    (root / 'diagnostic.json').write_text(json.dumps(diagnostic))
    factories = []
    for language in languages:
        if language in ('erlang', 'elixir'):
            factories.append(install_beam(root / language, language))
            continue
        if language == 'dotnet':
            factories.append(install_dotnet(root / language))
            continue
        if language == 'java':
            factories.append(install_java(root / language))
            continue
        if language in ('c', 'cpp'):
            factories.append(install_c(root / language, language))
            continue
        if language == 'node':
            factories.append(install_node(root / language))
            continue
        if language == 'rust':
            factories.append(install_rust(root / language))
            continue
        if language == 'ruby':
            factories.append(install_ruby(root / language))
            continue
        if language != 'python': raise ValueError('Unsupported catalog SDK proof language')
        target = root / language
        target.mkdir()
        env = {k: v for k, v in os.environ.items() if k not in ('PYTHONPATH', 'PYTHONHOME', 'TRANSIT_LIBRARY_DIR')}
        wheels = target / 'wheels'
        wheels.mkdir()
        for path in (ROOT / '.cache/bindings/wheels').glob('*.whl'):
            if path.name.split('-')[1] == '0.2.0' and path.name.split('-')[0] in ('transit_client', 'transit_native_client', 'transit_station', 'transit_native_station'):
                shutil.copy2(path, wheels / path.name)
        artifacts = {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in wheels.glob('*.whl')}
        assert len(artifacts) == 4
        (target / 'artifacts.json').write_text(json.dumps(artifacts))
        venv = target / 'venv'
        subprocess.run([sys.executable, '-m', 'venv', '--without-pip', str(venv)], check=True, env=env)
        python = str(venv / 'bin/python')
        subprocess.run([sys.executable, '-m', 'pip', '--python', python, 'install', '--no-index', '--find-links', str(wheels), 'transit-station==0.2.0'], check=True, env=env, stdout=subprocess.DEVNULL)
        script = target / 'consumer.py'
        shutil.copy2(ROOT / 'tests/python_catalog_sdk.py', script)
        values = target / 'values.py'
        shutil.copy2(ROOT / 'tests/python_catalog_values.py', values)
        subprocess.run([python, '-B', str(values)], check=True, env=env, cwd=target)
        for mode in ('sync', 'async'):
            def create(url, connection, state, mode=mode, python=python, script=script, target=target, env=env):
                config = target / f'{mode}.json'
                config.write_text(json.dumps(dict(url=url, connection=connection, seed_file=str(state / 'caller.seed'))))
                return Consumer([python, '-B', str(script), mode, str(config)], env, target)
            factories.append((f'python-{mode}', create))
    return factories


def install_node(target):
    target.mkdir()
    packages = target / 'packages'
    packages.mkdir()
    dependencies = {}
    artifacts = {}
    for name in ('client', 'native-client', 'station', 'native-station'):
        filename = f'transit-{name}-0.2.0.tgz'
        path = packages / filename
        shutil.copy2(ROOT / '.cache/bindings/node' / filename, path)
        dependencies[f'@transit/{name}'] = 'file:' + str(path)
        artifacts[filename] = hashlib.sha256(path.read_bytes()).hexdigest()
    (target / 'artifacts.json').write_text(json.dumps(artifacts))
    manifest = dict(private=True, type='module', packageManager=json.loads((ROOT / 'package.json').read_text())['packageManager'], dependencies=dependencies, pnpm=dict(overrides=dependencies))
    (target / 'package.json').write_text(json.dumps(manifest))
    environment = {k: v for k, v in os.environ.items() if k not in ('NODE_PATH', 'TRANSIT_HOST', 'TRANSIT_LIBRARY_DIR')}
    subprocess.run(['vp', 'env', 'exec', '--package-manager', manifest['packageManager'], 'pnpm', 'install', '--prefer-offline', '--ignore-scripts'], cwd=target, env=environment, check=True, stdout=subprocess.DEVNULL)
    script = target / 'consumer.mjs'
    shutil.copy2(ROOT / 'tests/node_catalog_sdk.mjs', script)
    def create(url, connection, state):
        config = target / 'client.json'
        config.write_text(json.dumps(dict(url=url, connection=connection, seed_file=str(state / 'caller.seed'))))
        return Consumer(['node', str(script), str(config)], environment, target)
    return 'node', create


def install_rust(target):
    target.mkdir()
    artifacts = {}
    names = ('transit-client', 'transit-native-client', 'transit-station-sdk', 'transit-native-station')
    for name in names:
        filename = f'{name}-0.2.0.crate'
        path = target / filename
        shutil.copy2(ROOT / '.cache/bindings/rust' / filename, path)
        artifacts[filename] = hashlib.sha256(path.read_bytes()).hexdigest()
        with tarfile.open(path) as archive: archive.extractall(target / 'vendor', filter='data')
    (target / 'artifacts.json').write_text(json.dumps(artifacts))
    (target / 'src').mkdir()
    shutil.copy2(ROOT / 'tests/rust_catalog_sdk.rs', target / 'src/main.rs')
    manifest = '[package]\nname = "transit-catalog-proof"\nversion = "0.1.0"\nedition = "2024"\n[dependencies]\ntransit-client = "=0.2.0"\ntransit-station-sdk = "=0.2.0"\nserde_json = { version = "=1.0.145", features = ["arbitrary_precision"] }\n[patch.crates-io]\n'
    manifest += ''.join(f'{name} = {{ path = "vendor/{name}-0.2.0" }}\n' for name in names)
    (target / 'Cargo.toml').write_text(manifest)
    lock = target / 'vendor/transit-station-sdk-0.2.0/Cargo.lock'
    shutil.copy2(lock, target / 'Cargo.lock')
    environment = {k:v for k,v in os.environ.items() if k not in ('TRANSIT_LIBRARY_DIR', 'LD_LIBRARY_PATH', 'LIBRARY_PATH')}
    subprocess.run(['cargo', 'test', '--offline', '-p', 'transit-station-sdk', '--lib'], cwd=target, env=environment, check=True)
    def registry(path):
        return {(p['name'], p['version'], p['checksum']) for p in tomllib.loads(path.read_text())['package'] if 'source' in p}
    selected = registry(target / 'Cargo.lock')
    assert selected and selected <= registry(lock)
    assert not any(name.startswith('arrow-') for name, _, _ in selected)
    subprocess.run(['cargo', 'build', '--locked', '--offline'], cwd=target, env=environment, check=True)
    executable = target / 'consumer'
    shutil.copy2(target / 'target/debug/transit-catalog-proof', executable)
    (target / 'src/main.rs').write_text('fn overlap(client: &mut transit_station_sdk::catalog::Client) { let a = &mut *client; let b = &mut *client; a.describe().unwrap(); b.describe().unwrap(); } fn main() {}')
    rejected = subprocess.run(['cargo', 'check', '--locked', '--offline'], cwd=target, env=environment, capture_output=True, text=True)
    assert rejected.returncode and 'cannot borrow `*client` as mutable more than once' in rejected.stderr, (rejected.returncode, rejected.stderr[-4096:])
    (target / 'src/main.rs').write_text('fn reused(client: transit_station_sdk::catalog::Client) { client.close().unwrap(); client.close().unwrap(); } fn main() {}')
    rejected = subprocess.run(['cargo', 'check', '--locked', '--offline'], cwd=target, env=environment, capture_output=True, text=True)
    assert rejected.returncode and 'use of moved value: `client`' in rejected.stderr, (rejected.returncode, rejected.stderr[-4096:])
    shutil.rmtree(target / 'vendor'); shutil.rmtree(target / 'target'); shutil.rmtree(target / 'src')
    def create(url, connection, state):
        config = target / 'client.json'
        config.write_text(json.dumps(dict(url=url, connection=connection, seed_file=str(state / 'caller.seed'))))
        return Consumer([str(executable), str(config)], environment, target)
    return 'rust', create


def install_ruby(target):
    target.mkdir()
    default = subprocess.check_output(['ruby', '-rrubygems', '-e', 'puts Gem.default_dir'], text=True).strip()
    environment = {k: v for k, v in os.environ.items() if k not in ('RUBYLIB', 'RUBYOPT', 'GEM_HOME', 'GEM_PATH', 'TRANSIT_HOST', 'TRANSIT_LIBRARY_DIR')}
    environment.update(GEM_HOME=str(target / 'gems'), GEM_PATH=f'{target / "gems"}:{default}')
    files = []
    artifacts = {}
    for name in ('transit-native-client-0.2.0-x86_64-linux.gem', 'transit-client-0.2.0.gem',
                 'transit-native-station-0.2.0-x86_64-linux.gem', 'transit-station-0.2.0.gem'):
        path = target / name
        shutil.copy2(ROOT / '.cache/bindings/ruby' / name, path)
        artifacts[name] = hashlib.sha256(path.read_bytes()).hexdigest()
        files.append(path)
    (target / 'artifacts.json').write_text(json.dumps(artifacts))
    subprocess.run(['gem', 'install', '--local', '--no-document', '--ignore-dependencies', *files], env=environment, cwd=target, check=True, stdout=subprocess.DEVNULL)
    script = target / 'consumer.rb'
    values = target / 'values.rb'
    shutil.copy2(ROOT / 'tests/ruby_catalog_sdk.rb', script)
    shutil.copy2(ROOT / 'tests/ruby_catalog_values.rb', values)
    shutil.copy2(ROOT / 'tests/ruby_schema_values.rb', target / 'schema_values.rb')
    subprocess.run(['ruby', str(values)], env=environment, cwd=target, check=True)
    def create(url, connection, state):
        config = target / 'client.json'
        config.write_text(json.dumps(dict(url=url, connection=connection, seed_file=str(state / 'caller.seed'))))
        return Consumer(['ruby', str(script), str(config)], environment, target)
    return 'ruby', create


class CatalogCConsumer(Consumer):
    def send(self, action):
        name, value = next(iter(action.items()))
        if name == 'scenario':
            command = f"scenario {value['index']}"
        else:
            assert name == 'close'
            command = name
        self.child.stdin.write(command + '\n'); self.child.stdin.flush()


def install_c(target, language, packages=ROOT / '.cache/bindings/c'):
    target.mkdir()
    prefix = target / 'installed'
    artifacts = {}
    for source in sorted(packages.glob('*.tar.gz')):
        if source.name.startswith('transit-sdk-examples-'): continue
        artifact = target / source.name
        shutil.copy2(source, artifact)
        artifacts[source.name] = hashlib.sha256(artifact.read_bytes()).hexdigest()
        with tarfile.open(artifact) as archive: archive.extractall(prefix, filter='data')
    assert len(artifacts) == 6
    (target / 'artifacts.json').write_text(json.dumps(artifacts))
    environment = {k:v for k,v in os.environ.items() if k not in ('TRANSIT_LIBRARY_DIR', 'LD_LIBRARY_PATH', 'LIBRARY_PATH', 'CPATH', 'CPLUS_INCLUDE_PATH', 'C_INCLUDE_PATH')}
    environment['PKG_CONFIG_PATH'] = str(prefix / 'lib/pkgconfig')
    flags = shlex.split(subprocess.check_output(['pkg-config', '--cflags', '--libs', 'transit-station-c' if language == 'c' else 'transit-station-cpp'], text=True, env=environment))
    source = target / ('c_catalog_sdk.c' if language == 'c' else 'cpp_catalog_sdk.cpp')
    shutil.copy2(ROOT / 'tests' / source.name, source)
    shutil.copy2(ROOT / 'tests/catalog_sdk_io.h', target / 'catalog_sdk_io.h')
    executable = target / 'consumer'
    subprocess.run(['zig', 'cc' if language == 'c' else 'c++', '-std=c11' if language == 'c' else '-std=c++17', '-Wall', '-Wextra', '-Werror', str(source), *flags, '-lpthread', '-o', str(executable)], cwd=target, env=environment, check=True)
    if language == 'cpp':
        for name in ('Client', 'Compiled', 'Prepared', 'SavedIntent'):
            source.write_text(f'#include <transit/catalog.hpp>\nvoid copy(transit::sdk::station::catalog::{name} &value) {{ auto other = value; }}')
            rejected = subprocess.run(['zig', 'c++', '-std=c++17', '-fsyntax-only', str(source), f'-I{prefix / "include"}'], cwd=target, env=environment, capture_output=True, text=True)
            assert rejected.returncode and 'deleted' in rejected.stderr
    source.unlink(); (target / 'catalog_sdk_io.h').unlink()
    if language == 'cpp':
        from c_catalog_values import run
        run(target / 'faults', prefix, flags, environment)
    def create(url, connection, state):
        s = connection['scope']
        arguments = [str(executable), url, str(state / 'caller.seed'), str(s['realm']), str(connection['principal']), str(connection['owner']), str(s['resource']), str(s['catalog']), str(state)]
        return CatalogCConsumer(arguments, environment, target)
    return language, create


def install_java(target, packages=ROOT / '.cache/bindings/java'):
    target.mkdir()
    library = target / 'lib'
    library.mkdir()
    artifacts = {}
    for name in ('transit-client', 'transit-native-client', 'transit-station-sdk', 'transit-native-station', 'gson'):
        filename = f'{name}-{"2.12.1" if name == "gson" else "0.2.0"}.jar'
        destination = library / filename
        shutil.copy2(packages / filename, destination)
        artifacts[filename] = hashlib.sha256(destination.read_bytes()).hexdigest()
    (target / 'artifacts.json').write_text(json.dumps(artifacts))
    environment = {k:v for k,v in os.environ.items() if k not in ('CLASSPATH', 'JAVA_TOOL_OPTIONS', '_JAVA_OPTIONS', 'JDK_JAVA_OPTIONS', 'TRANSIT_HOST', 'TRANSIT_LIBRARY_DIR')}
    sources = [target / name for name in ('JavaCatalogSdk.java', 'JavaCatalogValues.java', 'JavaLogicalValues.java', 'JavaSchemaValues.java')]
    for source in sources: shutil.copy2(ROOT / 'tests' / source.name, source)
    classes = target / 'classes'
    classes.mkdir()
    subprocess.run(['javac', '--release', '21', '-Xlint:all', '-Werror', '-cp', str(library / '*'), '-d', str(classes), *map(str, sources)], cwd=target, env=environment, check=True)
    for source in sources: source.unlink()
    subprocess.run(['java', f'-Djava.io.tmpdir={target}', '-cp', str(classes) + os.pathsep + str(library / '*'), 'JavaSchemaValues'], cwd=target, env=environment, check=True)
    faults = target / 'faults'
    faults.mkdir()
    with zipfile.ZipFile(library / 'transit-native-station-0.2.0.jar') as archive:
        (faults / 'native-host').write_bytes(archive.read('io/transit/nativestation/transit-station-host'))
    (faults / 'native-host').chmod(0o700)
    shutil.copy2(ROOT / 'tests/catalog_port_host.py', faults / 'host')
    (faults / 'host').chmod(0o700)
    classpath = str(classes) + os.pathsep + str(library / '*')
    subprocess.run(['java', f'-Djava.io.tmpdir={target}', '-cp', classpath, 'io.transit.sdk.station.JavaCatalogValues', str(faults)], cwd=target, env=environment, check=True, timeout=90)
    shutil.rmtree(faults)
    def create(url, connection, state):
        config = target / 'client.json'
        config.write_text(json.dumps(dict(url=url, connection=connection, seed_file=str(state / 'caller.seed'))))
        return Consumer(['java', f'-Djava.io.tmpdir={target}', '-cp', classpath, 'JavaCatalogSdk', str(config)], environment, target)
    return 'java', create


def install_dotnet(target, packages=ROOT / '.cache/bindings/dotnet'):
    import xml.etree.ElementTree as ET
    target.mkdir()
    source = target / 'source'
    source.mkdir()
    feed = target / 'feed'
    feed.mkdir()
    artifacts = {}
    for package in ('Transit.Client', 'Transit.Native.Client', 'Transit.Station.Sdk', 'Transit.Native.Station'):
        name = f'{package}.0.2.0.nupkg'
        destination = feed / name
        shutil.copy2(packages / name, destination)
        artifacts[name] = hashlib.sha256(destination.read_bytes()).hexdigest()
    (target / 'artifacts.json').write_text(json.dumps(artifacts))
    environment = {k:v for k,v in os.environ.items() if k not in ('TRANSIT_LIBRARY_DIR', 'LD_LIBRARY_PATH', 'LIBRARY_PATH')}
    environment.update(NUGET_PACKAGES=str(target / 'packages'), DOTNET_CLI_TELEMETRY_OPTOUT='1', DOTNET_NOLOGO='1')
    project = source / 'Consumer.csproj'
    project.write_text('''<Project Sdk="Microsoft.NET.Sdk">
<PropertyGroup><TargetFramework>net8.0</TargetFramework><OutputType>Exe</OutputType><ImplicitUsings>enable</ImplicitUsings><Nullable>enable</Nullable><TreatWarningsAsErrors>true</TreatWarningsAsErrors></PropertyGroup>
<ItemGroup><PackageReference Include="Transit.Client" Version="[0.2.0]" /><PackageReference Include="Transit.Station.Sdk" Version="[0.2.0]" /></ItemGroup>
</Project>''')
    config = ET.Element('configuration')
    sources = ET.SubElement(config, 'packageSources')
    ET.SubElement(sources, 'clear')
    ET.SubElement(sources, 'add', key='local-built', value=str(feed))
    ET.ElementTree(config).write(source / 'NuGet.Config', encoding='utf-8', xml_declaration=True)
    for name in ('DotnetCatalogSdk.cs', 'DotnetCatalogValues.cs', 'DotnetLogicalValues.cs', 'DotnetSchemaValues.cs'):
        shutil.copy2(ROOT / 'tests' / name, source / name)
    subprocess.run(['dotnet', 'restore', project.name, '--configfile', 'NuGet.Config'], cwd=source, env=environment, check=True)
    app = target / 'app'
    subprocess.run(['dotnet', 'build', project.name, '--no-restore', '-c', 'Release', '-o', str(app)], cwd=source, env=environment, check=True)
    shutil.rmtree(source)
    shutil.rmtree(target / 'packages')
    subprocess.run(['dotnet', str(app / 'Consumer.dll'), 'values', str(target)], cwd=target, env=environment, check=True, timeout=45)
    def create(url, connection, state):
        config = target / 'client.json'
        config.write_text(json.dumps(dict(url=url, connection=connection, seed_file=str(state / 'caller.seed'))))
        return Consumer(['dotnet', str(app / 'Consumer.dll'), str(config)], environment, target)
    return 'dotnet', create


def install_beam(target, language, packages=ROOT / '.cache/bindings/beam'):
    target.mkdir()
    library = target / 'lib'
    library.mkdir()
    classes = target / 'classes'
    classes.mkdir()
    names = ['transit_native_client', 'transit_client', 'transit_native_station', 'transit_station_sdk']
    if language == 'elixir': names += ['transit_client_elixir', 'transit_station_elixir']
    artifacts = {}
    for name in names:
        filename = f'{name}-0.2.0.tar.gz'
        path = target / filename
        shutil.copy2(packages / filename, path)
        artifacts[filename] = hashlib.sha256(path.read_bytes()).hexdigest()
        with tarfile.open(path) as archive: archive.extractall(library, filter='data')
    (target / 'artifacts.json').write_text(json.dumps(artifacts))
    environment = {k:v for k,v in os.environ.items() if k not in ('ERL_LIBS', 'ERL_FLAGS', 'TRANSIT_HOST', 'TRANSIT_LIBRARY_DIR')}
    environment.update(ERL_LIBS=str(library), ERL_FLAGS='+S 2:2 +SDcpu 1 +SDio 1')
    for name in ('beam_catalog_controller.erl', 'beam_catalog_values.erl', 'beam_schema_values.erl', 'beam_logical_values.erl'):
        source = target / name
        shutil.copy2(ROOT / 'tests' / name, source)
        subprocess.run(['erlc', '-Werror', '-o', str(classes), str(source)], cwd=target, env=environment, check=True)
        source.unlink()
    if language == 'elixir':
        source = target / 'elixir_catalog_adapter.ex'
        shutil.copy2(ROOT / 'tests' / source.name, source)
        subprocess.run(['elixirc', '--warnings-as-errors', '-pa', str(classes), '-o', str(classes), str(source)], cwd=target, env=environment, check=True)
        source.unlink()
        def command(module): return ['elixir', '-pa', str(classes), '-e', f':{module}.main(ElixirCatalogAdapter, System.argv())', '--']
    else:
        def command(module): return ['erl', '-noshell', '-pa', str(classes), '-eval', f'{module}:main(transit_catalog, init:get_plain_arguments()), halt().', '-extra']
    faults = target / 'faults'
    faults.mkdir()
    shutil.copy2(library / 'transit_native_station-0.2.0/priv/transit-station-host', faults / 'native-host')
    shutil.copy2(ROOT / 'tests/catalog_port_host.py', faults / 'host')
    (faults / 'host').chmod(0o700)
    subprocess.run([*command('beam_catalog_values'), str(faults)], cwd=target, env=environment, check=True, timeout=90)
    shutil.rmtree(faults)
    def create(url, connection, state):
        config = target / 'client.json'
        config.write_text(json.dumps(dict(url=url, connection=connection, seed_file=str(state / 'caller.seed'))))
        return Consumer([*command('beam_catalog_controller'), str(config)], environment, target)
    return language, create
