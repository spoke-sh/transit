"""Restore public raw NuGet artifacts outside the checkout and run shared authority proofs."""
from runner.paths import ROOT
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from sdk.sdk_raw_client import run as schedule


def run(node, cli, library, artifacts):
    root = ROOT
    def install(target):
        source = target / 'source'
        source.mkdir()
        feed = target / 'feed'
        feed.mkdir()
        for name in ('Transit.Client.0.2.0.nupkg', 'Transit.Native.Client.0.2.0.nupkg'):
            shutil.copy2(Path(artifacts).resolve() / name, feed / name)
        environment = dict(os.environ, NUGET_PACKAGES=str(target / 'packages'), DOTNET_CLI_TELEMETRY_OPTOUT='1', DOTNET_NOLOGO='1')
        project = source / 'Consumer.csproj'
        project.write_text('''<Project Sdk="Microsoft.NET.Sdk">
<PropertyGroup><TargetFramework>net8.0</TargetFramework><OutputType>Exe</OutputType><ImplicitUsings>enable</ImplicitUsings><Nullable>enable</Nullable><TreatWarningsAsErrors>true</TreatWarningsAsErrors></PropertyGroup>
<ItemGroup><PackageReference Include="Transit.Client" Version="[0.2.0]" /></ItemGroup>
</Project>\n''')
        config = ET.Element('configuration')
        sources = ET.SubElement(config, 'packageSources')
        ET.SubElement(sources, 'clear')
        ET.SubElement(sources, 'add', key='local-built', value=str(feed))
        ET.ElementTree(config).write(source / 'NuGet.Config', encoding='utf-8', xml_declaration=True)
        shutil.copy2(root / 'tests/sdk/consumers/dotnet/DotnetClientSdk.cs', source / 'Program.cs')
        shutil.copy2(root / 'tests/sdk/consumers/dotnet/DotnetSchemaValues.cs', source / 'DotnetSchemaValues.cs')
        shutil.copy2(root / 'tests/sdk/consumers/dotnet/DotnetNativeLifetime.cs', source)
        subprocess.run(['dotnet', 'restore', project.name, '--configfile', 'NuGet.Config'], env=environment, cwd=source, check=True)
        output = target / 'app'
        subprocess.run(['dotnet', 'build', project.name, '--no-restore', '-c', 'Release', '-o', str(output)], env=environment, cwd=source, check=True)
        shutil.rmtree(source)
        shutil.rmtree(target / 'packages')
        override = target / 'native-override'
        override.mkdir()
        shutil.copy2(library, override / 'libtransit_client.so')
        bad = target / 'bad-native'
        bad.mkdir()
        contract = json.loads((root / 'packages/zig/transit-client/abi-v1.json').read_text())
        fixture = bad / 'version.c'
        fixture.write_text('#include <stdint.h>\n' + '\n'.join(
            f'uint32_t {function["name"]}(void) {{ return {99 if function["name"] == "transit_client_abi_version" else 0}; }}'
            for function in contract['functions']))
        subprocess.run(['zig', 'cc', '-shared', '-fPIC', '-o', str(bad / 'libtransit_client.so'), str(fixture)], env=environment, cwd=target, check=True)
        fixture.unlink()
        first = True
        def invoke(mode, config):
            nonlocal first
            command = ['dotnet', str(output / 'Consumer.dll')]
            if first:
                native = output / 'Transit.Native.Client.dll'
                hidden = output / 'native.saved'
                native.rename(hidden)
                try:
                    subprocess.run([*command, 'missing-artifact', str(config)], env=environment, cwd=target, check=True, timeout=20)
                finally: hidden.rename(native)
                subprocess.run([*command, 'native-capacity', str(config)], env=environment, cwd=target, check=True, timeout=20)
                first = False
            return subprocess.check_output([*command, mode, str(config)], env=environment, cwd=target, timeout=40)
        return invoke
    schedule(node, cli, library, install, '.NET')


if __name__ == '__main__': run(*sys.argv[1:])
