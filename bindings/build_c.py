"""Package relocatable C/C++ SDK prefixes with standard pkg-config discovery."""
import io
import argparse
from pathlib import Path
import re
import tarfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = '0.2.0'


def build(output, native_prefix=None):
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    native_prefix = Path(native_prefix).resolve() if native_prefix else ROOT / 'zig-out'
    native = native_prefix / 'lib/libtransit_client.so'
    sdk = ROOT / 'packages/c/transit-client/zig-out/lib/libtransit_sdk_client.so'
    if not native.is_file() or not sdk.is_file():
        raise SystemExit('Run just bindings::c-build to compile both SDK and native dependency')
    packages = {
        'transit-native-client-c': {'lib/libtransit_client.so': native.read_bytes(),
            'include/transit_client.h': (ROOT / 'packages/zig/transit-client/include/transit_client.h').read_bytes()},
        'transit-client-c': {'lib/libtransit_sdk_client.so': sdk.read_bytes()},
        'transit-client-cpp': {},
        'transit-native-station-c': {'lib/libtransit_station.so': (native_prefix / 'lib/libtransit_station.so').read_bytes(),
            'include/transit_station.h': (ROOT / 'packages/zig/transit-station-bindings/include/transit_station.h').read_bytes()},
        'transit-station-c': {'lib/libtransit_sdk_station.so': (ROOT / 'packages/c/transit-station/zig-out/lib/libtransit_sdk_station.so').read_bytes()},
        'transit-station-cpp': {},
        'transit-sdk-examples-c': {'lib/libtransit_sdk_examples_c.a': (ROOT / 'examples/station-sdk/c/zig-out/lib/libtransit_sdk_examples_c.a').read_bytes(),
            'bin/transit-c-counter': (ROOT / 'examples/station-sdk/c/zig-out/bin/transit-c-counter').read_bytes()},
        'transit-sdk-examples-cpp': {'bin/transit-cpp-counter': (ROOT / 'examples/station-sdk/cpp/zig-out/bin/transit-cpp-counter').read_bytes()},
    }
    specifications = [
        ('transit-client-c', 'packages/c/transit-client', 'transit_sdk_client', ['transit-native-client-c']),
        ('transit-client-cpp', 'packages/cpp/transit-client', '', ['transit-client-c']),
        ('transit-station-c', 'packages/c/transit-station', 'transit_sdk_station', ['transit-client-c', 'transit-native-station-c']),
        ('transit-station-cpp', 'packages/cpp/transit-station-sdk', '', ['transit-station-c', 'transit-client-cpp']),
        ('transit-sdk-examples-c', 'examples/station-sdk/c', 'transit_sdk_examples_c', ['transit-station-c']),
        ('transit-sdk-examples-cpp', 'examples/station-sdk/cpp', '', ['transit-sdk-examples-c', 'transit-station-cpp']),
    ]
    for name, source, library, dependencies in specifications:
        package = ROOT / source
        version = re.search(r'\.version = "([^"]+)"', (package / 'build.zig.zon').read_text())
        if not version or version[1] != VERSION: raise SystemExit(f'Artifact version drift: {source}')
        for path in sorted((package / 'include').rglob('*')):
            if path.is_file(): packages[name][str(path.relative_to(package))] = path.read_bytes()
        for path in [package / 'README.md', *sorted((package / 'docs').glob('*.md'))]:
            packages[name][f'share/doc/{name}/{path.name}'] = path.read_bytes()
        libraries = '-L${libdir} -Wl,-rpath,${libdir} -l' + library if library else ''
        requires = ', '.join(f'{dependency} = {VERSION}' for dependency in dependencies)
        packages[name][f'lib/pkgconfig/{name}.pc'] = (
            'prefix=${pcfiledir}/../..\nlibdir=${prefix}/lib\nincludedir=${prefix}/include\n'
            f'Name: {name}\nDescription: Typed Transit SDK\nVersion: {VERSION}\n'
            f'Requires: {requires}\nCflags: -I${{includedir}}\nLibs: {libraries}\n').encode()
    for family in ('client', 'station'):
        name = f'transit-native-{family}-c'
        packages[name][f'lib/pkgconfig/{name}.pc'] = (
            f'Name: {name}\nDescription: Transit native ABI dependency\nVersion: {VERSION}\n').encode()
    for name, files in packages.items():
        platform = '' if name in ('transit-client-cpp', 'transit-station-cpp') else '-linux-x86_64'
        artifact = output / f'{name}-{VERSION}{platform}.tar.gz'
        with tarfile.open(artifact, 'w:gz') as archive:
            for relative, data in sorted(files.items()):
                entry = tarfile.TarInfo(relative)
                entry.size, entry.mode = len(data), 0o755 if relative.endswith('.so') or relative.startswith('bin/') else 0o644
                archive.addfile(entry, io.BytesIO(data))
        print(f'Built {artifact.name}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output')
    parser.add_argument('--native-prefix')
    args = parser.parse_args()
    build(args.output, args.native_prefix)
