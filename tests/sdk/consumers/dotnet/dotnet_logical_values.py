"""Qualify owned logical models from isolated installed .NET artifacts."""

from sdk.artifact_versions import package_text
from runner.paths import ROOT
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET


def run(artifacts):
    root = ROOT
    with tempfile.TemporaryDirectory(prefix='transit-dotnet-logical-') as temporary:
        target = Path(temporary)
        feed = target / 'feed'
        feed.mkdir()
        identities = {}
        for package in ('Transit.Client', 'Transit.Native.Client', 'Transit.Station.Sdk', 'Transit.Native.Station'):
            name = package_text(f'{package}.0.0.1.nupkg', 'dotnet')
            shutil.copy2(Path(artifacts).resolve() / name, feed / name)
            identities[name] = hashlib.sha256((feed / name).read_bytes()).hexdigest()
        (target / 'artifacts.json').write_text(json.dumps(identities))
        source = target / 'source'
        source.mkdir()
        (source / 'Proof.csproj').write_text(package_text('''<Project Sdk="Microsoft.NET.Sdk">
<PropertyGroup><TargetFramework>net8.0</TargetFramework><OutputType>Exe</OutputType><ImplicitUsings>enable</ImplicitUsings><Nullable>enable</Nullable><TreatWarningsAsErrors>true</TreatWarningsAsErrors></PropertyGroup>
<ItemGroup><PackageReference Include="Transit.Station.Sdk" Version="[0.0.1]" /></ItemGroup></Project>''', 'dotnet'))
        config = ET.Element('configuration')
        sources = ET.SubElement(config, 'packageSources')
        ET.SubElement(sources, 'clear')
        ET.SubElement(sources, 'add', key='built', value=str(feed))
        ET.ElementTree(config).write(source / 'NuGet.Config', encoding='utf-8', xml_declaration=True)
        shutil.copy2(root / 'tests/sdk/consumers/dotnet/DotnetLogicalValues.cs', source)
        shutil.copy2(root / 'tests/sdk/consumers/dotnet/DotnetSchemaValues.cs', source)
        shutil.copy2(root / 'tests/sdk/consumers/dotnet/DotnetHandlerTables.cs', source)
        (source / 'Program.cs').write_text('SchemaValues.Run(); LogicalValues.Run(); HandlerTables.Run(); System.Console.WriteLine(".NET owned logical values and recursive schemas passed.");\n')
        environment = {k: v for k, v in os.environ.items() if k not in ('TRANSIT_LIBRARY_DIR', 'LD_LIBRARY_PATH', 'LIBRARY_PATH')}
        environment.update(NUGET_PACKAGES=str(target / 'packages'), DOTNET_CLI_TELEMETRY_OPTOUT='1', DOTNET_NOLOGO='1')
        subprocess.run(['dotnet', 'restore', 'Proof.csproj', '--configfile', 'NuGet.Config'], cwd=source, env=environment, check=True)
        output = target / 'app'
        subprocess.run(['dotnet', 'build', 'Proof.csproj', '--no-restore', '-c', 'Release', '-o', str(output)], cwd=source, env=environment, check=True)
        shutil.rmtree(source)
        shutil.rmtree(target / 'packages')
        subprocess.run(['dotnet', str(output / 'Proof.dll')], cwd=target, env=environment, check=True, timeout=45)
        print(json.dumps(dict(profile='installed-dotnet-logical-values', artifacts=identities)))


if __name__ == '__main__':
    run(*sys.argv[1:])
