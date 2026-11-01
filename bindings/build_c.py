"""Package relocatable C/C++ SDK prefixes with standard pkg-config discovery."""
import io
import argparse
import json
from pathlib import Path
import re
import subprocess
import tarfile
import tempfile

from package_metadata import BASE_VERSION, rewrite, rewrite_tree, version

ROOT = Path(__file__).resolve().parents[1]
VERSION = version('c')


def installed_binary(path, runtime_library_path):
    # Zig's linked artifacts can contain absolute dependency-cache rpaths.
    # Rewrite a private copy: installation must load SDK peers from this prefix,
    # while keeping the selected build's explicit runtime closure.
    rpath = '$ORIGIN/../lib' if path.parent.name == 'bin' else '$ORIGIN'
    if runtime_library_path:
        rpath += ':' + runtime_library_path
    with tempfile.TemporaryDirectory(prefix='transit-c-package-') as directory:
        copy = Path(directory) / path.name
        copy.write_bytes(path.read_bytes())
        subprocess.run(['patchelf', '--set-rpath', rpath, str(copy)], check=True)
        return copy.read_bytes()


def build(output, native_prefix, sdk_prefix):
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    native_prefix = Path(native_prefix).resolve()
    native = native_prefix / 'lib/libtransit_client.so'
    sdk_prefix = Path(sdk_prefix).resolve()
    native_build = json.loads((native_prefix / 'build.json').read_text())
    sdk_build = json.loads((sdk_prefix / 'build.json').read_text())
    for name in ('optimize', 'target', 'cpu', 'resolved_cpu', 'compiler', 'runtime_library_path'):
        if native_build[name] != sdk_build[name]:
            raise SystemExit(f'Mismatched native/C SDK build input: {name}')
    if native_build['set'] != 'clients' or sdk_build['set'] != 'c-sdk':
        raise SystemExit('Wrong native/C SDK artifact family')
    for family in ('client', 'station'):
        name = f'contracts/{family}.json'
        if (native_prefix / name).read_bytes() != (sdk_prefix / name).read_bytes():
            raise SystemExit('Mismatched native/C SDK contract definition')
    sdk = sdk_prefix / 'lib/libtransit_sdk_client.so'
    if not native.is_file() or not sdk.is_file():
        raise SystemExit('Run just bindings::c-build to compile both SDK and native dependency')
    packages = {
        'transit-native-client-c': {'lib/libtransit_client.so': native.read_bytes(),
            'include/transit_client.h': (ROOT / 'packages/zig/transit-client/include/transit_client.h').read_bytes()},
        'transit-client-c': {'lib/libtransit_sdk_client.so': installed_binary(sdk, sdk_build['runtime_library_path'])},
        'transit-client-cpp': {},
        'transit-native-station-c': {'lib/libtransit_station.so': (native_prefix / 'lib/libtransit_station.so').read_bytes(),
            'include/transit_station.h': (ROOT / 'packages/zig/transit-station-bindings/include/transit_station.h').read_bytes()},
        'transit-station-c': {'lib/libtransit_sdk_station.so': installed_binary(sdk_prefix / 'lib/libtransit_sdk_station.so', sdk_build['runtime_library_path'])},
        'transit-station-cpp': {},
        'transit-sdk-examples-c': {'lib/libtransit_sdk_examples_c.a': (sdk_prefix / 'lib/libtransit_sdk_examples_c.a').read_bytes(),
            'bin/transit-c-counter': installed_binary(sdk_prefix / 'bin/transit-c-counter', sdk_build['runtime_library_path'])},
        'transit-sdk-examples-cpp': {'bin/transit-cpp-counter': installed_binary(sdk_prefix / 'bin/transit-cpp-counter', sdk_build['runtime_library_path'])},
    }
    specifications = [
        ('transit-client-c', 'sdks/c/transit-client', 'transit_sdk_client', ['transit-native-client-c']),
        ('transit-client-cpp', 'sdks/cpp/transit-client', '', ['transit-client-c']),
        ('transit-station-c', 'sdks/c/transit-station', 'transit_sdk_station', ['transit-client-c', 'transit-native-station-c']),
        ('transit-station-cpp', 'sdks/cpp/transit-station-sdk', '', ['transit-station-c', 'transit-client-cpp']),
        ('transit-sdk-examples-c', 'examples/station-sdk/c', 'transit_sdk_examples_c', ['transit-station-c']),
        ('transit-sdk-examples-cpp', 'examples/station-sdk/cpp', '', ['transit-sdk-examples-c', 'transit-station-cpp']),
    ]
    for name, source, library, dependencies in specifications:
        package = ROOT / source
        version = re.search(r'\.version = "([^"]+)"', (package / 'build.zig.zon').read_text())
        if not version or version[1] != BASE_VERSION: raise SystemExit(f'Artifact version drift: {source}')
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
        platform = '' if name in ('transit-client-cpp', 'transit-station-cpp') else '-linux-' + native_build['target'].split('-')[0]
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
    parser.add_argument('--native-prefix', required=True)
    parser.add_argument('--sdk-prefix', required=True)
    args = parser.parse_args()
    build(args.output, args.native_prefix, args.sdk_prefix)
