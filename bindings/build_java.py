"""Build independent Java JARs/POMs with pinned direct dependencies and native resources."""
from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
VERSION = '0.2.0'


def build(output, names):
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    gson = Path(os.environ['TRANSIT_GSON_JAR'])
    (output / 'gson-2.12.1.jar').unlink(missing_ok=True)
    shutil.copy2(gson, output / 'gson-2.12.1.jar')
    for name in names:
        source = ROOT / 'packages/java' / name
        tree = ET.parse(source / 'pom.xml')
        ns = {'m': 'http://maven.apache.org/POM/4.0.0'}
        assert tree.findtext('m:artifactId', namespaces=ns) == name
        assert tree.findtext('m:version', namespaces=ns) == VERSION
        dependencies = tree.findall('m:dependencies/m:dependency', ns)
        classpath = []
        for dependency in dependencies:
            artifact = dependency.findtext('m:artifactId', namespaces=ns)
            version = dependency.findtext('m:version', namespaces=ns)
            scope = dependency.findtext('m:scope', namespaces=ns)
            target = output / f'{artifact}-{version}.jar'
            assert target.is_file(), f'Build dependency first: {target.name}'
            if scope != 'runtime': classpath.append(str(target))
        with tempfile.TemporaryDirectory(prefix='transit-java-build-') as temporary:
            classes = Path(temporary) / 'classes'
            classes.mkdir()
            if (source / 'resources').is_dir(): shutil.copytree(source / 'resources', classes, dirs_exist_ok=True)
            if name.startswith('transit-native-'):
                family = name.removeprefix('transit-native-')
                target = classes / 'io/transit' / f'native{family}'
                assert (target / 'version').read_text() == VERSION + '\n'
                shutil.copy2(ROOT / 'zig-out/bin' / f'transit-{family}-host', target)
            sources = sorted((source / 'src').rglob('*.java'))
            if sources:
                subprocess.run(['javac', '--release', '21', '-Xlint:all', '-Werror', '-cp', os.pathsep.join(classpath), '-d', str(classes), *map(str, sources)], check=True)
            metadata = classes / 'META-INF/maven/io.transit' / name
            metadata.mkdir(parents=True)
            shutil.copy2(source / 'pom.xml', metadata / 'pom.xml')
            manifest = Path(temporary) / 'MANIFEST.MF'
            manifest.write_text(f'Manifest-Version: 1.0\nImplementation-Version: {VERSION}\nAutomatic-Module-Name: io.transit.{name.removeprefix("transit-").replace("-", ".")}\n\n')
            artifact = output / f'{name}-{VERSION}.jar'
            subprocess.run(['jar', '--create', '--file', str(artifact), '--manifest', str(manifest), '-C', str(classes), '.'], check=True)
            shutil.copy2(source / 'pom.xml', output / f'{name}-{VERSION}.pom')
            print(f'Built {artifact.name}')


if __name__ == '__main__':
    build(sys.argv[1], sys.argv[2:] or ['transit-native-client', 'transit-client'])
