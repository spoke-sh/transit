"""Install Java SDK/example JARs and run the shared Station authority schedule."""
from runner.paths import ROOT
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile
from sdk.sdk_station_runner import Consumer, run as schedule
from sdk.sdk_http_runner import run as http_schedule


def run(node, cli, library, artifacts, http_worker=None, *, execute=None):
    if execute is None and http_worker is None:
        raise ValueError("The full Station SDK schedule requires the HTTP worker binary")
    root = ROOT
    def install(target):
        environment = {k: v for k, v in os.environ.items() if k not in ('CLASSPATH', 'JAVA_TOOL_OPTIONS', '_JAVA_OPTIONS', 'JDK_JAVA_OPTIONS', 'TRANSIT_HOST')}
        lib = target / 'lib'
        lib.mkdir()
        for name in ('transit-client-0.2.0.jar', 'transit-native-client-0.2.0.jar', 'transit-station-sdk-0.2.0.jar',
                     'transit-native-station-0.2.0.jar', 'transit-sdk-examples-0.2.0.jar', 'gson-2.12.1.jar'):
            shutil.copy2(Path(artifacts).resolve() / name, lib / name)
        source = target / 'JavaStationSdk.java'
        shutil.copy2(root / 'tests/sdk/consumers/java/JavaStationSdk.java', source)
        classes = target / 'classes'
        classes.mkdir()
        subprocess.run(['javac', '--release', '21', '-Xlint:all', '-Werror', '-cp', str(lib / '*'), '-d', str(classes), str(source)], env=environment, cwd=target, check=True)
        source.unlink()
        values = target / 'JavaHandlerTables.java'
        shutil.copy2(root / 'tests/sdk/consumers/java/JavaHandlerTables.java', values)
        subprocess.run(['javac', '--release', '21', '-Xlint:all', '-Werror', '-cp', str(lib / '*'), '-d', str(classes), str(values)], env=environment, cwd=target, check=True)
        values.unlink()
        subprocess.run(['java', '-cp', os.pathsep.join((str(classes), str(lib / '*'))), 'io.transit.sdk.station.JavaHandlerTables'], env=environment, cwd=target, check=True, timeout=30)
        smoke = target / 'StationArtifactCheck.java'
        smoke.write_text('''import io.transit.client.*;
import io.transit.sdk.station.Station;
import io.transit.examples.*;
public final class StationArtifactCheck {
    private StationArtifactCheck() {}
    public static void main(String[] args) {
        try {
            Station.encodeCast(new Messages.Read(), Codecs.COUNTER);
            throw new AssertionError("Mismatched SDK artifact was accepted");
        } catch (TransitException error) {
            if (error.kind() != TransitException.Kind.INCOMPATIBLE_NATIVE) throw error;
        }
    }
}
''')
        subprocess.run(['javac', '--release', '21', '-Xlint:all', '-Werror', '-cp', str(lib / '*'), '-d', str(classes), str(smoke)], env=environment, cwd=target, check=True)
        smoke.unlink()
        mismatched = target / 'mismatched-client.jar'
        with zipfile.ZipFile(lib / 'transit-client-0.2.0.jar') as original, zipfile.ZipFile(mismatched, 'w') as altered:
            for entry in original.infolist():
                data = original.read(entry)
                if entry.filename == 'META-INF/MANIFEST.MF': data = data.replace(b'Implementation-Version: 0.2.0', b'Implementation-Version: 99.0.0')
                altered.writestr(entry, data)
        dependencies = sorted(path for path in lib.glob('*.jar') if path.name != 'transit-client-0.2.0.jar')
        subprocess.run(['java', f'-Djava.io.tmpdir={target}', '-cp', os.pathsep.join(map(str, [classes, mismatched, *dependencies])), 'StationArtifactCheck'], env=environment, cwd=target, check=True, timeout=20)
        mismatched.unlink()
        # Generic state and Table APIs reject values of the wrong public type.
        invalid = target / 'WrongValue.java'
        for body in ('turn.state().put(Handlers.TOTAL, true);', 'new Table.Row(new Table.RowIdentity(new byte[20]), java.util.List.of(true));'):
            invalid.write_text('import io.transit.sdk.station.*; import io.transit.examples.Handlers;\n'
                               f'public final class WrongValue {{ void invalid(Turn turn) {{ {body} }} }}\n')
            result = subprocess.run(['javac', '--release', '21', '-cp', str(lib / '*'), '-d', str(classes), str(invalid)], env=environment, cwd=target, capture_output=True, text=True)
            assert result.returncode != 0 and 'incompatible bounds' in result.stderr, result.stderr
        invalid.unlink()
        fake = target / 'bad-station-version'
        fake.write_text(f'#!{sys.executable}\nimport sys\nsys.stdin.readline()\nprint(\'{{"status":0,"value":{{"host_version":1,"station_version":99,"transit_version":1}}}}\')\n')
        fake.chmod(0o700)
        classpath = os.pathsep.join((str(classes), str(lib / '*')))
        grpc_fixtures = target / 'grpc-fixtures.json'
        shutil.copy2(root / 'packages/zig/transit-station-grpc/src/fixtures/service.json', grpc_fixtures)
        golden = target / 'grpc-golden.json'
        golden.write_text(json.dumps({'profile': 'native_v1', 'grpc_fixtures': str(grpc_fixtures)}))
        subprocess.run(['java', f'-Djava.io.tmpdir={target}', '-cp', classpath, 'JavaStationSdk', 'grpc-golden', str(golden)], env=environment, cwd=target, check=True, timeout=30)
        return Consumer(environment, lambda mode, config: ['java', f'-Djava.io.tmpdir={target}', '-cp', classpath, 'JavaStationSdk', mode, str(config)],
            lambda config, role: ['java', f'-Djava.io.tmpdir={target}', '-cp', str(lib / '*'), 'io.transit.examples.CounterMain', str(config), role, '--commits', '1'],
            'thread-handler', extra_failures=('error-stop', 'error-block'), arrow_adapter=False)
    (execute or schedule)(node, cli, library, install, 'Java')
    if execute is None: http_schedule(node, cli, library, http_worker, install, 'Java', public_release=True, public_followup=True)


if __name__ == '__main__': run(*sys.argv[1:])
