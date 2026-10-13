"""Restore public Station NuGet packages and run the shared authority schedule."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from sdk_station_runner import Consumer, run as schedule
from sdk_http_runner import run as http_schedule


def run(node, cli, library, artifacts, http_worker=None, *, execute=None):
    if execute is None and http_worker is None:
        raise ValueError("The full Station SDK schedule requires the HTTP worker binary")
    root = Path(__file__).resolve().parents[1]
    def install(target):
        source = target / 'source'
        source.mkdir()
        feed = target / 'feed'
        feed.mkdir()
        for package in ('Transit.Client', 'Transit.Native.Client', 'Transit.Station.Sdk', 'Transit.Native.Station', 'Transit.Sdk.Examples'):
            name = f'{package}.0.2.0.nupkg'
            shutil.copy2(Path(artifacts).resolve() / name, feed / name)
        environment = dict(os.environ, NUGET_PACKAGES=str(target / 'packages'), DOTNET_CLI_TELEMETRY_OPTOUT='1', DOTNET_NOLOGO='1')
        project = source / 'Consumer.csproj'
        project.write_text('''<Project Sdk="Microsoft.NET.Sdk">
<PropertyGroup><TargetFramework>net8.0</TargetFramework><OutputType>Exe</OutputType><ImplicitUsings>enable</ImplicitUsings><Nullable>enable</Nullable><TreatWarningsAsErrors>true</TreatWarningsAsErrors></PropertyGroup>
<ItemGroup><PackageReference Include="Transit.Client" Version="[0.2.0]" /><PackageReference Include="Transit.Station.Sdk" Version="[0.2.0]" /><PackageReference Include="Transit.Sdk.Examples" Version="[0.2.0]" /></ItemGroup>
</Project>\n''')
        config = ET.Element('configuration')
        sources = ET.SubElement(config, 'packageSources')
        ET.SubElement(sources, 'clear')
        ET.SubElement(sources, 'add', key='local-built', value=str(feed))
        ET.ElementTree(config).write(source / 'NuGet.Config', encoding='utf-8', xml_declaration=True)
        shutil.copy2(root / 'tests/DotnetStationSdk.cs', source / 'Program.cs')
        shutil.copy2(root / 'tests/DotnetHandlerTables.cs', source)
        shutil.copy2(root / 'tests/DotnetNativeLifetime.cs', source)
        subprocess.run(['dotnet', 'restore', project.name, '--configfile', 'NuGet.Config'], env=environment, cwd=source, check=True)
        output = target / 'app'
        subprocess.run(['dotnet', 'build', project.name, '--no-restore', '-c', 'Release', '-o', str(output)], env=environment, cwd=source, check=True)
        subprocess.run(['dotnet', str(output / 'Consumer.dll'), 'handler-tables'], env=environment, cwd=target, check=True, timeout=30)
        # Both typed keys and logical Table rows reject values of the wrong type.
        original = (source / 'Program.cs').read_text()
        for body in ('turn.State.Put(StateKeys.Total, true);', 'new TableRow(new RowIdentity(new byte[20]), new bool[] { true });'):
            (source / 'Program.cs').write_text('using Transit.Station.Sdk; using Transit.Sdk.Examples; class Wrong { static void Main() {} void Bad(Turn turn) { ' + body + ' } }\n')
            result = subprocess.run(['dotnet', 'build', project.name, '--no-restore', '-c', 'Release'], env=environment, cwd=source, capture_output=True, text=True)
            assert result.returncode != 0 and ('CS0411' in result.stdout or 'CS1503' in result.stdout), result.stdout
        (source / 'Program.cs').write_text(original)
        shutil.rmtree(source)
        shutil.rmtree(target / 'packages')
        bad = target / 'bad-station-version'
        bad.mkdir()
        contract = json.loads((root / 'packages/zig/transit-station-bindings/abi-v1.json').read_text())
        fixture = bad / 'version.c'
        fixture.write_text('#include <stdint.h>\n' + '\n'.join(
            f'uint32_t {function["name"]}(void) {{ return {99 if function["name"] == "station_abi_version" else 0}; }}'
            for function in contract['functions']))
        subprocess.run(['zig', 'cc', '-shared', '-fPIC', '-o', str(bad / 'libtransit_station.so'), str(fixture)], env=environment, cwd=target, check=True)
        fixture.unlink()
        grpc_fixtures = target / 'grpc-fixtures.json'
        shutil.copy2(root / 'packages/zig/transit-station-grpc/src/fixtures/service.json', grpc_fixtures)
        golden = target / 'grpc-golden.json'
        golden.write_text(json.dumps({'profile': 'native_v1', 'grpc_fixtures': str(grpc_fixtures)}))
        subprocess.run(['dotnet', str(output / 'Consumer.dll'), 'grpc-golden', str(golden)], env=environment, cwd=target, check=True, timeout=30)
        def command(mode, config):
            if mode.startswith(('http-', 'grpc-', 'document-')):
                return ['dotnet', str(output / 'Consumer.dll'), mode, str(config)]
            # Establish a durable private directory entry before the proof's store
            # truncates, writes and Flush(true)s each exact frozen mutation.
            cfg = json.loads(config.read_text())
            pending = Path(cfg['pending'])
            if not pending.exists():
                with open(os.open(pending, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), 'wb') as file: os.fsync(file.fileno())
                directory = os.open(pending.parent, os.O_RDONLY | os.O_DIRECTORY)
                try: os.fsync(directory)
                finally: os.close(directory)
            return ['dotnet', str(output / 'Consumer.dll'), mode, str(config)]
        return Consumer(environment, command,
            lambda config, role: ['dotnet', 'exec', '--depsfile', str(output / 'Consumer.deps.json'), '--runtimeconfig', str(output / 'Consumer.runtimeconfig.json'),
                                  str(output / 'Transit.Sdk.Examples.dll'), str(config), role, '--commits', '1'], 'async-handler', arrow_adapter=False)
    (execute or schedule)(node, cli, library, install, '.NET')
    if execute is None: http_schedule(node, cli, library, http_worker, install, '.NET', public_release=True, public_followup=True)


if __name__ == '__main__': run(*sys.argv[1:])
