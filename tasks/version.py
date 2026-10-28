#!/usr/bin/env python3
"""Check Transit's lockstep package versions and optional release tag."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import tomllib
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
RELEASE = re.compile(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)')


def package_versions(path):
    """Yield owned package versions and exact owned dependency requirements."""
    text = path.read_text()
    if path.name == 'build.zig.zon':
        yield re.search(r'\.version\s*=\s*"([^"]+)"', text)[1]
    elif path.name == 'package.json':
        data = json.loads(text)
        if 'version' in data:
            yield data['version']
        for group in ('dependencies', 'devDependencies', 'peerDependencies', 'optionalDependencies'):
            for name, version in data.get(group, {}).items():
                if name.startswith('@transit/') and version != 'workspace:*':
                    yield version.removeprefix('workspace:')
    elif path.name in ('Cargo.toml', 'pyproject.toml'):
        data = tomllib.loads(text)
        package = data.get('package', data.get('project', {}))
        if 'version' in package:
            yield package['version']
        if path.name == 'Cargo.toml':
            for group in ('dependencies', 'dev-dependencies', 'build-dependencies'):
                for name, value in data.get(group, {}).items():
                    if name.startswith('transit-'):
                        version = value.get('version') if isinstance(value, dict) else value
                        if version is not None:
                            yield version.removeprefix('=')
        else:
            for dependency in package.get('dependencies', []):
                if dependency.startswith('transit-'):
                    yield dependency.split('==', 1)[-1]
    elif path.name == 'Cargo.lock':
        for package in tomllib.loads(text)['package']:
            if package['name'].startswith('transit-'):
                yield package['version']
    elif path.suffix == '.csproj':
        tree = ET.fromstring(text)
        version = tree.findtext('PropertyGroup/Version')
        if version:
            yield version
        for dependency in tree.findall('.//PackageReference'):
            if dependency.attrib['Include'].startswith('Transit.'):
                yield dependency.attrib['Version'].strip('[]')
    elif path.name == 'pom.xml':
        tree = ET.fromstring(text)
        ns = {'m': 'http://maven.apache.org/POM/4.0.0'}
        yield tree.findtext('m:version', namespaces=ns)
        for dependency in tree.findall('m:dependencies/m:dependency', ns):
            if dependency.findtext('m:groupId', namespaces=ns) == 'io.transit':
                yield dependency.findtext('m:version', namespaces=ns)
    elif path.suffix == '.gemspec':
        yield from re.findall(r"spec\.version\s*=\s*'([^']+)'", text)
        yield from re.findall(r"spec\.add_dependency\s+'transit-[^']+',\s*'= ([^']+)'", text)
    elif path.name == 'mix.exs':
        yield from re.findall(r'version:\s*"([^"]+)"', text)
        yield from re.findall(r'\{:transit_\w+,\s*"== ([^"]+)"', text)
    elif path.name == 'rebar.config':
        yield from re.findall(r'\{transit_\w+,\s*"([^"]+)"', text)
    elif path.name.endswith('.app.src'):
        yield from re.findall(r'\{vsn,\s*"([^"]+)"', text)
    elif path.name == 'version' and 'resources' in path.parts:
        yield text.strip()
    elif path.name == 'go.mod':
        yield from re.findall(r'github\.com/spoke-sh/transit/sdks/go v([^\s]+)', text)
    elif path.name == 'Chart.yaml':
        yield from re.findall(r'^(?:version|appVersion):\s*"?([^"\s]+)"?\s*$', text, re.M)


def check(root, tag=None):
    version = (root / 'VERSION').read_text().strip()
    if not RELEASE.fullmatch(version):
        raise ValueError('VERSION must be MAJOR.MINOR.PATCH without leading zeroes')
    # Use the repository inventory, excluding generated build outputs and dependencies.
    names = subprocess.check_output(['git', 'ls-files', '-z'], cwd=root).decode().split('\0')
    errors = []
    count = 0
    for name in names:
        if not name or name.startswith(('third_party/', 'tests/', 'docs/history/')):
            continue
        path = root / name
        if not (path.name in ('build.zig.zon', 'package.json', 'Cargo.toml', 'Cargo.lock',
                             'pyproject.toml', 'pom.xml', 'mix.exs', 'rebar.config',
                             'version', 'go.mod', 'Chart.yaml') or path.suffix in ('.csproj', '.gemspec')
                or path.name.endswith('.app.src')):
            continue
        for actual in package_versions(path):
            count += 1
            if actual != version:
                errors.append(f'{name}: expected {version}, found {actual}')
    if tag is not None:
        if tag != f'v{version}':
            errors.append(f'release tag must be v{version}, found {tag}')
        else:
            head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root)
            tagged = subprocess.check_output(['git', 'rev-parse', f'refs/tags/{tag}^{{commit}}'], cwd=root)
            if head != tagged:
                errors.append(f'{tag} does not identify HEAD')
        if subprocess.check_output(['git', 'status', '--porcelain'], cwd=root):
            errors.append('tag qualification requires a clean checkout')
    if errors:
        raise ValueError('\n'.join(errors))
    return version, count


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tag', help='require an exact vMAJOR.MINOR.PATCH tag at clean HEAD')
    args = parser.parse_args()
    try:
        version, count = check(ROOT, args.tag)
    except (ValueError, subprocess.CalledProcessError) as error:
        parser.exit(1, f'{error}\n')
    print(f'Transit {version}: {count} package versions and dependency pins agree')
