"""Build isolated public .NET packages with exact local native dependencies."""
from pathlib import Path
import argparse
import os
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def build(output, names, native_prefix=ROOT / 'zig-out'):
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    for name in names:
        source = ROOT / name if '/' in name else ROOT / 'packages/dotnet' / name
        with tempfile.TemporaryDirectory(prefix='transit-dotnet-build-') as temporary:
            target = Path(temporary)
            shutil.copytree(source, target, dirs_exist_ok=True)
            manifest, = target.glob('*.csproj')
            project = ET.parse(manifest)
            assert project.findtext('PropertyGroup/Version') == '0.2.0'
            if name.startswith('transit-native-'):
                family = name.removeprefix('transit-native-')
                (target / 'native').mkdir()
                shutil.copy2(native_prefix / 'lib' / f'libtransit_{family}.so', target / 'native')
            # Avoid inherited package feeds and package caches. Every public SDK
            # dependency is resolved from this task's actual built artifact.
            config = ET.Element('configuration')
            sources = ET.SubElement(config, 'packageSources')
            ET.SubElement(sources, 'clear')
            ET.SubElement(sources, 'add', key='transit-local', value=str(output))
            ET.ElementTree(config).write(target / 'NuGet.Config', encoding='utf-8', xml_declaration=True)
            environment = dict(os.environ, NUGET_PACKAGES=str(target / 'packages'), DOTNET_CLI_TELEMETRY_OPTOUT='1', DOTNET_NOLOGO='1')
            subprocess.run(['dotnet', 'restore', manifest.name, '--configfile', 'NuGet.Config', '--disable-parallel'], env=environment, cwd=target, check=True)
            subprocess.run(['dotnet', 'pack', manifest.name, '--no-restore', '-c', 'Release', '-o', str(output)], env=environment, cwd=target, check=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('packages', nargs='*')
    parser.add_argument('--native-prefix', type=Path, default=ROOT / 'zig-out')
    args = parser.parse_args()
    build(args.output, args.packages or ['transit-native-client', 'transit-client', 'transit-native-station', 'transit-station-sdk', 'examples/station-sdk/dotnet'], args.native_prefix.resolve())
