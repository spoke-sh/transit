"""Installed direct catalog consumers against the shared fault/restart service."""
from runner.paths import ROOT
import hashlib
import json
import os
from pathlib import Path
import shutil
import shlex
import subprocess
import sys
import tarfile
import tomllib
import zipfile

from sdk.sdk_unified import Consumer



def exercise(wheels, root, authority, service, profile, restart, policy):
    target = root / 'installed-python'
    target.mkdir()
    packages = target / 'wheels'
    packages.mkdir()
    names = {'transit_client', 'transit_native_client', 'transit_station', 'transit_native_station'}
    artifacts = {}
    for path in Path(wheels).glob('*.whl'):
        if path.name.split('-')[0] not in names or path.name.split('-')[1] != '0.0.1': continue
        shutil.copy2(path, packages / path.name)
        artifacts[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
        if path.name.split('-')[0] == 'transit_station':
            with zipfile.ZipFile(path) as archive:
                for name in ('catalog.py', 'catalog_values.py', 'relational.py', 'station-abi.json'):
                    assert archive.read('transit_station/' + name) == (ROOT / 'sdks/python/transit-station/transit_station' / name).read_bytes(), 'Rebuild matching Python wheels'
    assert len(artifacts) == 4
    (target / 'artifacts.json').write_text(json.dumps(artifacts))
    env = {k: v for k, v in os.environ.items() if k not in ('PYTHONPATH', 'PYTHONHOME', 'TRANSIT_LIBRARY_DIR')}
    venv = target / 'venv'
    subprocess.run([sys.executable, '-m', 'venv', '--without-pip', str(venv)], env=env, check=True)
    python = str(venv / 'bin/python')
    subprocess.run([sys.executable, '-m', 'pip', '--python', python, 'install', '--no-index', '--find-links', str(packages), 'transit-station==0.0.1'],
                   env=env, check=True, stdout=subprocess.DEVNULL)
    script = target / 'consumer.py'
    shutil.copy2(ROOT / 'tests/sdk/consumers/python/python_catalog_sdk.py', script)
    history_fixture = target / 'history-fixture.json'
    shutil.copy2(ROOT / 'packages/zig/transit-catalog/src/fixtures/direct-history-host-v1.json', history_fixture)
    for test in ('python_catalog_values.py', 'python_relational_values.py'):
        shutil.copy2(ROOT / 'tests/sdk/consumers/python' / test, target / test)
        subprocess.run([python, '-B', str(target / test), *([str(history_fixture)] if test == 'python_catalog_values.py' else [])], cwd=target, env=env, check=True)
    seed = target / 'caller.seed'
    seed.write_text('7b'*32); seed.chmod(0o600)
    c = profile['catalog']
    connection = dict(scope=dict(c['scope'], catalog=str(c['scope']['catalog'])), branch='1', audience=c['audience'], principal=941002, role=profile['role'])
    config = target / 'client.json'
    config.write_text(json.dumps(dict(url=authority, service_url=service, connection=connection, seed_file=str(seed))))
    def connect(mode): return Consumer([python, '-B', str(script), mode, str(config)], env, target, read_timeout=180)
    schedule(target, ('sync', 'async'), connect, restart, policy, historical_catalog=True)


def schedule(target, modes, connect, restart, policy, *, retained_sql=True, historical_catalog=False):
    for mode in modes:
        consumer = connect(mode)
        def replace():
            nonlocal consumer
            consumer.child.kill(); consumer.child.wait(timeout=15); consumer.close()
            restart()
            consumer = connect(mode)
        try:
            assert consumer.call({'prepare': {}})['uncertain']
            original = (target / mode / 'original.json').read_bytes()
            intent = (target / mode / 'intent.json').read_bytes()
            replace()
            assert consumer.call({'recover': {}})['retention_uncertain']
            acquisition = (target / mode / 'acquisition.json').read_bytes()
            replace()
            assert consumer.call({'retained': {}})['opened' if retained_sql else 'retained']
            if historical_catalog:
                assert consumer.call({'history_begin': {}})['history_uncertain']
                historical_original = (target / mode / 'history-acquisition.json').read_bytes()
                replace()
                assert consumer.call({'retained': {}})['opened']
                assert consumer.call({'history_recover': {}})['published']
            policy(False)
            try:
                assert consumer.call({'denied': dict(ordinal=0)})['denied']
                if historical_catalog: assert consumer.call({'history_denied': {}})['denied']
            finally: policy(True)
            assert consumer.call({'rows' if retained_sql else 'metadata': {}}) == (dict(rows=9, complete=True) if retained_sql else dict(rows=9, columns=2))
            policy(False)
            try: assert consumer.call({'denied': dict(ordinal=9)})['denied']
            finally: policy(True)
            assert consumer.call({'retire': {}})['original']
            if historical_catalog: assert consumer.call({'history_inspect': {}})['original']
            assert consumer.call({'rows' if retained_sql else 'metadata': {}}) == (dict(rows=9, complete=True) if retained_sql else dict(rows=9, columns=2))
            assert consumer.call({'release': {}})['release_uncertain']
            replace()
            assert consumer.call({'verify': {}})['recovered']
            if historical_catalog:
                assert consumer.call({'history_release': {}})['history_release_uncertain']
                historical_control = (target / mode / 'history-control.json').read_bytes()
                replace()
                assert consumer.call({'history_finish': {}})['released']
                assert (target / mode / 'history-acquisition.json').read_bytes() == historical_original
                assert (target / mode / 'history-control.json').read_bytes() == historical_control
            assert (target / mode / 'original.json').read_bytes() == original
            assert (target / mode / 'intent.json').read_bytes() == intent
            assert (target / mode / 'acquisition.json').read_bytes() == acquisition
        finally: consumer.close()


def exercise_node(packages, root, authority, service, profile, restart, policy):
    target = root / 'installed-node'
    target.mkdir()
    copies = target / 'packages'
    copies.mkdir()
    artifacts, dependencies = {}, {}
    for name in ('client', 'native-client', 'station', 'native-station'):
        path = Path(packages).resolve() / f'transit-{name}-0.0.1.tgz'
        copy = copies / path.name
        shutil.copy2(path, copy)
        artifacts[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
        dependencies['@transit/' + name] = 'file:' + str(copy)
        if name == 'station':
            with tarfile.open(path) as archive:
                for filename in ('catalog.js', 'relational.js', 'contract.json'):
                    assert archive.extractfile('package/dist/' + filename).read() == (ROOT / 'sdks/ts/transit-station-sdk/dist' / filename).read_bytes(), 'Rebuild matching Node packages'
    (target / 'artifacts.json').write_text(json.dumps(artifacts))
    manager = json.loads((ROOT / 'package.json').read_text())['packageManager']
    (target / 'package.json').write_text(json.dumps(dict(private=True, type='module', packageManager=manager, dependencies=dependencies, pnpm=dict(overrides=dependencies))))
    env = {k: v for k, v in os.environ.items() if k not in ('NODE_PATH', 'TRANSIT_HOST', 'TRANSIT_LIBRARY_DIR')}
    subprocess.run(['vp', 'env', 'exec', '--package-manager', manager, 'pnpm', 'install', '--prefer-offline', '--ignore-scripts'], cwd=target, env=env, check=True, stdout=subprocess.DEVNULL)
    script = target / 'consumer.mjs'
    shutil.copy2(ROOT / 'tests/sdk/consumers/node/node_catalog_sdk.mjs', script)
    seed = target / 'caller.seed'
    seed.write_text('7b'*32); seed.chmod(0o600)
    c = profile['catalog']
    connection = dict(scope=dict(c['scope'], catalog=str(c['scope']['catalog'])), branch='1', audience=c['audience'], principal=941002, role=profile['role'])
    config = target / 'client.json'
    config.write_text(json.dumps(dict(url=authority, service_url=service, connection=connection, seed_file=str(seed))))
    def connect(mode):
        assert mode == 'node'
        return Consumer(['node', str(script), str(config)], env, target, read_timeout=180)
    schedule(target, ('node',), connect, restart, policy, historical_catalog=True)


def exercise_ruby(packages, root, authority, service, profile, restart, policy):
    target = root / 'installed-ruby'
    target.mkdir()
    default = subprocess.check_output(['ruby', '-rrubygems', '-e', 'puts Gem.default_dir'], text=True).strip()
    env = {k: v for k, v in os.environ.items() if k not in ('RUBYLIB', 'RUBYOPT', 'GEM_HOME', 'GEM_PATH', 'TRANSIT_HOST', 'TRANSIT_LIBRARY_DIR')}
    env.update(GEM_HOME=str(target / 'gems'), GEM_PATH=f'{target / "gems"}:{default}')
    files, artifacts = [], {}
    for name in ('transit-client-0.0.1.gem', 'transit-native-client-0.0.1-x86_64-linux.gem',
                 'transit-station-0.0.1.gem', 'transit-native-station-0.0.1-x86_64-linux.gem'):
        path = target / name
        shutil.copy2(Path(packages) / name, path)
        artifacts[name] = hashlib.sha256(path.read_bytes()).hexdigest()
        files.append(str(path))
    (target / 'artifacts.json').write_text(json.dumps(artifacts))
    subprocess.run(['gem', 'install', '--local', '--no-document', '--ignore-dependencies', *files], env=env, cwd=target, check=True, stdout=subprocess.DEVNULL)
    installed = target / 'gems/gems/transit-station-0.0.1/lib/transit/station'
    for filename in ('catalog.rb', 'catalog_values.rb', 'bridge.rb', 'contract.json', 'schemas.json'):
        assert (installed / filename).read_bytes() == (ROOT / 'sdks/ruby/transit-station/lib/transit/station' / filename).read_bytes(), 'Rebuild matching Ruby gems'
    for test in ('ruby_catalog_values.rb', 'ruby_schema_values.rb', 'ruby_catalog_sdk.rb'):
        shutil.copy2(ROOT / 'tests/sdk/consumers/ruby' / test, target / test)
    subprocess.run(['ruby', str(target / 'ruby_catalog_values.rb')], env=env, cwd=target, check=True)
    seed = target / 'caller.seed'
    seed.write_text('7b'*32); seed.chmod(0o600)
    c = profile['catalog']
    connection = dict(scope=dict(c['scope'], catalog=str(c['scope']['catalog'])), branch='1', audience=c['audience'], principal=941002, role=profile['role'])
    config = target / 'client.json'
    config.write_text(json.dumps(dict(url=authority, service_url=service, connection=connection, seed_file=str(seed))))
    def connect(mode):
        assert mode == 'ruby'
        return Consumer(['ruby', str(target / 'ruby_catalog_sdk.rb'), str(config)], env, target, read_timeout=180)
    schedule(target, ('ruby',), connect, restart, policy, retained_sql=False)


def exercise_java(packages, root, authority, service, profile, restart, policy):
    target = root / 'installed-java'
    target.mkdir()
    library = target / 'lib'
    library.mkdir()
    artifacts = {}
    for name in ('transit-client', 'transit-native-client', 'transit-station-sdk', 'transit-native-station', 'gson'):
        filename = f'{name}-{"2.12.1" if name == "gson" else "0.0.1"}.jar'
        destination = library / filename
        shutil.copy2(Path(packages) / filename, destination)
        artifacts[filename] = hashlib.sha256(destination.read_bytes()).hexdigest()
    (target / 'artifacts.json').write_text(json.dumps(artifacts))
    env = {k: v for k, v in os.environ.items() if k not in ('CLASSPATH', 'JAVA_TOOL_OPTIONS', '_JAVA_OPTIONS', 'JDK_JAVA_OPTIONS', 'TRANSIT_HOST', 'TRANSIT_LIBRARY_DIR')}
    with zipfile.ZipFile(library / 'transit-station-sdk-0.0.1.jar') as archive:
        assert archive.read('io/transit/sdk/station/contract.json') == (ROOT / 'sdks/java/transit-station-sdk/resources/io/transit/sdk/station/contract.json').read_bytes()
    sources = [target / name for name in ('JavaCatalogSdk.java', 'JavaCatalogValues.java', 'JavaLogicalValues.java', 'JavaSchemaValues.java')]
    for source in sources: shutil.copy2(ROOT / 'tests/sdk/consumers/java' / source.name, source)
    classes = target / 'classes'
    classes.mkdir()
    subprocess.run(['javac', '--release', '21', '-Xlint:all', '-Werror', '-cp', str(library / '*'), '-d', str(classes), *map(str, sources)], cwd=target, env=env, check=True)
    for source in sources: source.unlink()
    classpath = str(classes) + os.pathsep + str(library / '*')
    subprocess.run(['java', f'-Djava.io.tmpdir={target}', '-cp', classpath, 'JavaSchemaValues'], cwd=target, env=env, check=True)
    faults = target / 'faults'
    faults.mkdir()
    with zipfile.ZipFile(library / 'transit-native-station-0.0.1.jar') as archive:
        (faults / 'native-host').write_bytes(archive.read('io/transit/nativestation/transit-station-host'))
    (faults / 'native-host').chmod(0o700)
    shutil.copy2(ROOT / 'tests/catalog/tables/direct_catalog_port_host.py', faults / 'host')
    (faults / 'host').chmod(0o700)
    subprocess.run(['java', f'-Djava.io.tmpdir={target}', '-cp', classpath, 'io.transit.sdk.station.JavaCatalogValues', str(faults)], cwd=target, env=env, check=True, timeout=90)
    seed = target / 'caller.seed'
    seed.write_text('7b'*32); seed.chmod(0o600)
    c = profile['catalog']
    connection = dict(scope=dict(c['scope'], catalog=str(c['scope']['catalog'])), branch='1', audience=c['audience'], principal=941002, role=profile['role'])
    config = target / 'client.json'
    config.write_text(json.dumps(dict(url=authority, service_url=service, connection=connection, seed_file=str(seed))))
    def connect(mode):
        assert mode == 'java'
        return Consumer(['java', f'-Djava.io.tmpdir={target}', '-cp', classpath, 'JavaCatalogSdk', str(config)], env, target, read_timeout=180)
    schedule(target, ('java',), connect, restart, policy, retained_sql=False)


def exercise_dotnet(packages, root, authority, service, profile, restart, policy):
    import xml.etree.ElementTree as ET
    target = root / 'installed-dotnet'
    target.mkdir()
    source, feed = target / 'source', target / 'feed'
    source.mkdir(); feed.mkdir()
    artifacts = {}
    for name in ('Transit.Client', 'Transit.Native.Client', 'Transit.Station.Sdk', 'Transit.Native.Station'):
        filename = f'{name}.0.0.1.nupkg'
        destination = feed / filename
        shutil.copy2(Path(packages) / filename, destination)
        artifacts[filename] = hashlib.sha256(destination.read_bytes()).hexdigest()
    (target / 'artifacts.json').write_text(json.dumps(artifacts))
    env = {k: v for k, v in os.environ.items() if k not in ('TRANSIT_LIBRARY_DIR', 'LD_LIBRARY_PATH', 'LIBRARY_PATH')}
    env.update(NUGET_PACKAGES=str(target / 'packages'), DOTNET_CLI_TELEMETRY_OPTOUT='1', DOTNET_NOLOGO='1')
    project = source / 'Consumer.csproj'
    project.write_text('''<Project Sdk="Microsoft.NET.Sdk">
<PropertyGroup><TargetFramework>net8.0</TargetFramework><OutputType>Exe</OutputType><ImplicitUsings>enable</ImplicitUsings><Nullable>enable</Nullable><TreatWarningsAsErrors>true</TreatWarningsAsErrors></PropertyGroup>
<ItemGroup><PackageReference Include="Transit.Client" Version="[0.0.1]" /><PackageReference Include="Transit.Station.Sdk" Version="[0.0.1]" /></ItemGroup>
</Project>''')
    configuration = ET.Element('configuration')
    sources = ET.SubElement(configuration, 'packageSources')
    ET.SubElement(sources, 'clear')
    ET.SubElement(sources, 'add', key='local-built', value=str(feed))
    ET.ElementTree(configuration).write(source / 'NuGet.Config', encoding='utf-8', xml_declaration=True)
    for name in ('DotnetCatalogSdk.cs', 'DotnetCatalogValues.cs', 'DotnetLogicalValues.cs', 'DotnetSchemaValues.cs'):
        shutil.copy2(ROOT / 'tests/sdk/consumers/dotnet' / name, source / name)
    subprocess.run(['dotnet', 'restore', project.name, '--configfile', 'NuGet.Config'], cwd=source, env=env, check=True)
    app = target / 'app'
    subprocess.run(['dotnet', 'build', project.name, '--no-restore', '-c', 'Release', '-o', str(app)], cwd=source, env=env, check=True)
    shutil.rmtree(source); shutil.rmtree(target / 'packages')
    subprocess.run(['dotnet', str(app / 'Consumer.dll'), 'values', str(target)], cwd=target, env=env, check=True, timeout=45)
    seed = target / 'caller.seed'
    seed.write_text('7b'*32); seed.chmod(0o600)
    c = profile['catalog']
    connection = dict(scope=dict(c['scope'], catalog=str(c['scope']['catalog'])), branch='1', audience=c['audience'], principal=941002, role=profile['role'])
    config = target / 'client.json'
    config.write_text(json.dumps(dict(url=authority, service_url=service, connection=connection, seed_file=str(seed))))
    def connect(mode):
        assert mode == 'dotnet'
        return Consumer(['dotnet', str(app / 'Consumer.dll'), str(config)], env, target, read_timeout=180)
    schedule(target, ('dotnet',), connect, restart, policy, retained_sql=False)


def exercise_rust(packages, root, authority, service, profile, restart, policy):
    target = root / 'installed-rust'
    target.mkdir()
    names = ('transit-client', 'transit-native-client', 'transit-station-sdk', 'transit-native-station')
    artifacts = {}
    for name in names:
        filename = f'{name}-0.0.1.crate'
        destination = target / filename
        shutil.copy2(Path(packages) / filename, destination)
        artifacts[filename] = hashlib.sha256(destination.read_bytes()).hexdigest()
        with tarfile.open(destination) as archive: archive.extractall(target / 'vendor', filter='data')
    (target / 'artifacts.json').write_text(json.dumps(artifacts))
    for filename in ('catalog.rs', 'bridge.rs', 'contract.json'):
        assert (target / 'vendor/transit-station-sdk-0.0.1/src' / filename).read_bytes() == (ROOT / 'sdks/rust/transit-station-sdk/src' / filename).read_bytes(), 'Rebuild matching Rust crates'
    (target / 'src').mkdir()
    shutil.copy2(ROOT / 'tests/sdk/consumers/rust/rust_catalog_sdk.rs', target / 'src/main.rs')
    manifest = '[package]\nname = "transit-direct-catalog-proof"\nversion = "0.1.0"\nedition = "2024"\n[dependencies]\ntransit-client = "=0.0.1"\ntransit-station-sdk = "=0.0.1"\nserde_json = { version = "=1.0.145", features = ["arbitrary_precision"] }\n[patch.crates-io]\n'
    manifest += ''.join(f'{name} = {{ path = "vendor/{name}-0.0.1" }}\n' for name in names)
    (target / 'Cargo.toml').write_text(manifest)
    lock = target / 'vendor/transit-station-sdk-0.0.1/Cargo.lock'
    shutil.copy2(lock, target / 'Cargo.lock')
    env = {k:v for k,v in os.environ.items() if k not in ('TRANSIT_LIBRARY_DIR', 'LD_LIBRARY_PATH', 'LIBRARY_PATH')}
    env['RUSTFLAGS'] = '-Dwarnings'
    subprocess.run(['cargo', 'test', '--offline', '-p', 'transit-station-sdk', '--lib'], cwd=target, env=env, check=True)
    def registry(path): return {(p['name'],p['version'],p['checksum']) for p in tomllib.loads(path.read_text())['package'] if 'source' in p}
    selected = registry(target / 'Cargo.lock')
    assert selected and selected <= registry(lock)
    assert not any(name.startswith('arrow-') for name,_,_ in selected)
    subprocess.run(['cargo', 'build', '--locked', '--offline'], cwd=target, env=env, check=True)
    executable = target / 'consumer'
    shutil.copy2(target / 'target/debug/transit-direct-catalog-proof', executable)
    (target / 'src/main.rs').write_text('fn overlap(client: &mut transit_station_sdk::catalog::Client) { let a = &mut *client; let b = &mut *client; a.describe().unwrap(); b.describe().unwrap(); } fn main() {}')
    rejected = subprocess.run(['cargo', 'check', '--locked', '--offline'], cwd=target, env=env, capture_output=True, text=True)
    assert rejected.returncode and 'cannot borrow `*client` as mutable more than once' in rejected.stderr, rejected.stderr[-4096:]
    (target / 'src/main.rs').write_text('fn reused(client: transit_station_sdk::catalog::Client) { client.close().unwrap(); client.close().unwrap(); } fn main() {}')
    rejected = subprocess.run(['cargo', 'check', '--locked', '--offline'], cwd=target, env=env, capture_output=True, text=True)
    assert rejected.returncode and 'use of moved value: `client`' in rejected.stderr, rejected.stderr[-4096:]
    shutil.rmtree(target / 'vendor'); shutil.rmtree(target / 'target'); shutil.rmtree(target / 'src')
    seed = target / 'caller.seed'
    seed.write_text('7b'*32); seed.chmod(0o600)
    c = profile['catalog']
    connection = dict(scope=dict(c['scope'],catalog=str(c['scope']['catalog'])),branch='1',audience=c['audience'],principal=941002,role=profile['role'])
    config = target / 'client.json'
    config.write_text(json.dumps(dict(url=authority,service_url=service,connection=connection,seed_file=str(seed),expected_authority=c['authority'])))
    def connect(mode):
        assert mode == 'rust'
        return Consumer([str(executable),str(config)],env,target,read_timeout=180)
    schedule(target,('rust',),connect,restart,policy,retained_sql=False)


def exercise_beam(packages, root, authority, service, profile, restart, policy):
    target = root / 'installed-beam'
    target.mkdir()
    library, classes = target / 'lib', target / 'classes'
    library.mkdir(); classes.mkdir()
    names = ('transit_native_client','transit_client','transit_client_elixir','transit_native_station','transit_station_sdk','transit_station_elixir')
    artifacts = {}
    for name in names:
        filename = f'{name}-0.0.1.tar.gz'
        destination = target / filename
        shutil.copy2(Path(packages) / filename,destination)
        artifacts[filename] = hashlib.sha256(destination.read_bytes()).hexdigest()
        with tarfile.open(destination) as archive: archive.extractall(library,filter='data')
    (target / 'artifacts.json').write_text(json.dumps(artifacts))
    assert (library / 'transit_station_sdk-0.0.1/priv/contract.json').read_bytes() == (ROOT / 'sdks/beam/transit-station-sdk/priv/contract.json').read_bytes()
    env = {k:v for k,v in os.environ.items() if k not in ('ERL_LIBS','ERL_FLAGS','TRANSIT_HOST','TRANSIT_LIBRARY_DIR')}
    env.update(ERL_LIBS=str(library),ERL_FLAGS='+S 2:2 +SDcpu 1 +SDio 1')
    for name in ('beam_catalog_controller.erl','beam_catalog_values.erl','beam_schema_values.erl','beam_logical_values.erl'):
        source = target / name
        shutil.copy2(ROOT / 'tests/sdk/consumers/beam' / name,source)
        subprocess.run(['erlc','-Werror','-o',str(classes),str(source)],cwd=target,env=env,check=True)
        source.unlink()
    source = target / 'elixir_catalog_adapter.ex'
    shutil.copy2(ROOT / 'tests/sdk/consumers/elixir' / source.name,source)
    subprocess.run(['elixirc','--warnings-as-errors','-pa',str(classes),'-o',str(classes),str(source)],cwd=target,env=env,check=True)
    source.unlink()
    def command(mode,module):
        if mode == 'erlang': return ['erl','-noshell','-pa',str(classes),'-eval',f'{module}:main(transit_catalog, init:get_plain_arguments()), halt().','-extra']
        assert mode == 'elixir'
        return ['elixir','-pa',str(classes),'-e',f':{module}.main(ElixirCatalogAdapter, System.argv())','--']
    faults = target / 'faults'
    faults.mkdir()
    shutil.copy2(library / 'transit_native_station-0.0.1/priv/transit-station-host',faults / 'native-host')
    shutil.copy2(ROOT / 'tests/catalog/tables/direct_catalog_port_host.py',faults / 'host'); (faults / 'host').chmod(0o700)
    for mode in ('erlang','elixir'):
        subprocess.run([*command(mode,'beam_catalog_values'),str(faults)],cwd=target,env=env,check=True,timeout=150)
    shutil.rmtree(faults)
    seed = target / 'caller.seed'; seed.write_text('7b'*32); seed.chmod(0o600)
    c = profile['catalog']
    connection = dict(scope=dict(c['scope'],catalog=str(c['scope']['catalog'])),branch='1',audience=c['audience'],principal=941002,role=profile['role'])
    def connect(mode):
        config = target / f'client-{mode}.json'
        config.write_text(json.dumps(dict(url=authority,service_url=service,connection=connection,seed_file=str(seed),mode=mode)))
        return Consumer([*command(mode,'beam_catalog_controller'),str(config)],env,target,read_timeout=180)
    schedule(target,('erlang','elixir'),connect,restart,policy,retained_sql=False)


class DirectCConsumer(Consumer):
    def send(self, action):
        name, = action
        assert name in ('prepare', 'recover', 'retained', 'denied', 'metadata', 'retire', 'release', 'verify', 'close')
        self.child.stdin.write(name + '\n'); self.child.stdin.flush()


def exercise_c(packages, root, authority, service, profile, restart, policy):
    target = root / 'installed-c'
    target.mkdir()
    prefix = target / 'installed'
    artifacts = {}
    for source in sorted(Path(packages).glob('*.tar.gz')):
        if source.name.startswith('transit-sdk-examples-'): continue
        artifact = target / source.name
        shutil.copy2(source, artifact)
        artifacts[source.name] = hashlib.sha256(artifact.read_bytes()).hexdigest()
        with tarfile.open(artifact) as archive: archive.extractall(prefix, filter='data')
    assert len(artifacts) == 6
    (target / 'artifacts.json').write_text(json.dumps(artifacts))
    for path in ('sdks/c/transit-station/include/transit/catalog.h', 'sdks/c/transit-station/include/transit/definition_station.h',
                 'sdks/cpp/transit-station-sdk/include/transit/catalog.hpp', 'sdks/cpp/transit-station-sdk/include/transit/catalog_values.hpp'):
        assert (prefix / 'include/transit' / Path(path).name).read_bytes() == (ROOT / path).read_bytes(), 'Rebuild matching C/C++ artifacts'
    env = {k: v for k, v in os.environ.items() if k not in ('TRANSIT_LIBRARY_DIR', 'LD_LIBRARY_PATH', 'LIBRARY_PATH', 'CPATH', 'CPLUS_INCLUDE_PATH', 'C_INCLUDE_PATH')}
    env['PKG_CONFIG_PATH'] = str(prefix / 'lib/pkgconfig')
    for language, source in (('c', 'c_catalog_sdk.c'), ('cpp', 'cpp_catalog_sdk.cpp')):
        flags = shlex.split(subprocess.check_output(['pkg-config', '--cflags', '--libs', 'transit-station-' + language], text=True, env=env))
        shutil.copy2(ROOT / 'tests/sdk/consumers' / language / source, target / source)
        shutil.copy2(ROOT / 'tests/sdk/catalog_sdk_io.h', target / 'catalog_sdk_io.h')
        subprocess.run(['zig', 'cc' if language == 'c' else 'c++', '-std=c11' if language == 'c' else '-std=c++17', '-Wall', '-Wextra', '-Werror', str(target / source), *flags, '-lpthread', '-o', str(target / language)], cwd=target, env=env, check=True)
        (target / source).unlink()
        if language == 'cpp':
            for name in ('Client', 'Compiled', 'SavedIntent', 'Reference', 'SnapshotAcquisition', 'Snapshot'):
                probe = target / 'copy.cpp'
                probe.write_text(f'#include <transit/catalog.hpp>\nvoid copy(transit::sdk::station::catalog::{name} &value) {{ auto other = value; }}')
                rejected = subprocess.run(['zig', 'c++', '-std=c++17', '-fsyntax-only', str(probe), f'-I{prefix / "include"}'], cwd=target, env=env, capture_output=True, text=True)
                assert rejected.returncode and 'deleted' in rejected.stderr
                probe.unlink()
    (target / 'catalog_sdk_io.h').unlink()
    from sdk.consumers.c.c_catalog_values import run as boundary_checks
    boundary_checks(target / 'faults', prefix, flags, env)
    seed = target / 'caller.seed'
    seed.write_text('7b'*32); seed.chmod(0o600)
    c = profile['catalog']; s = c['scope']
    def connect(mode):
        directory = target / (mode + '-state')
        directory.mkdir(exist_ok=True)
        return DirectCConsumer([str(target / mode), mode, authority, str(seed), str(s['realm']), '941002', str(c['audience']), str(s['resource']), str(s['catalog']), str(directory), service, str(profile['role'])], env, target, read_timeout=180)
    # Executable and saved-state directories have different names; the schedule
    # snapshots only immutable original files, then kills each consumer/node.
    def state_connect(mode): return connect(mode.removesuffix('-state'))
    schedule(target, ('c-state', 'cpp-state'), state_connect, restart, policy, retained_sql=False)
