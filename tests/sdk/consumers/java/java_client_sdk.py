"""Install independent Java JARs and run the shared public raw-client schedule."""
from runner.paths import ROOT
import os
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile
from sdk.sdk_raw_client import run as schedule


def run(node, cli, library, artifacts):
    root = ROOT
    def install(target):
        environment = {k: v for k, v in os.environ.items() if k not in ('CLASSPATH', 'JAVA_TOOL_OPTIONS', '_JAVA_OPTIONS', 'JDK_JAVA_OPTIONS', 'TRANSIT_HOST')}
        lib = target / 'lib'
        lib.mkdir()
        for name in ('transit-client-0.0.1.jar', 'transit-native-client-0.0.1.jar', 'gson-2.12.1.jar'):
            shutil.copy2(Path(artifacts).resolve() / name, lib / name)
        source = target / 'JavaClientSdk.java'
        shutil.copy2(root / 'tests/sdk/consumers/java/JavaClientSdk.java', source)
        classes = target / 'classes'
        classes.mkdir()
        subprocess.run(['javac', '--release', '21', '-Xlint:all', '-Werror', '-cp', str(lib / '*'), '-d', str(classes), str(source)], env=environment, cwd=target, check=True)
        source.unlink()
        schema_source = target / 'JavaSchemaValues.java'
        shutil.copy2(root / 'tests/sdk/consumers/java' / schema_source.name, schema_source)
        subprocess.run(['javac', '--release', '21', '-Xlint:all', '-Werror', '-cp', str(lib / '*'), '-d', str(classes), str(schema_source)], env=environment, cwd=target, check=True)
        schema_source.unlink()
        subprocess.run(['java', f'-Djava.io.tmpdir={target}', '-cp', os.pathsep.join((str(classes), str(lib / '*'))), 'JavaSchemaValues'], env=environment, cwd=target, check=True)
        # Missing and mismatched native artifacts must fail without starting I/O.
        smoke = target / 'ArtifactCheck.java'
        smoke.write_text('''import io.transit.client.*;
public final class ArtifactCheck {
    private ArtifactCheck() {}
    public static void main(String[] args) {
        try (Client client = Client.open(new ClientConfig(java.net.URI.create("http://127.0.0.1:1"), ClientConfig.Profile.NATIVE_V1))) {
            throw new AssertionError("Unexpected compatible artifact: " + client);
        } catch (TransitException error) {
            if (error.kind() != TransitException.Kind.INCOMPATIBLE_NATIVE) throw error;
        }
    }
}
''')
        subprocess.run(['javac', '--release', '21', '-Xlint:all', '-Werror', '-cp', str(lib / '*'), '-d', str(classes), str(smoke)], env=environment, cwd=target, check=True)
        smoke.unlink()
        raw_classpath = os.pathsep.join(map(str, (classes, lib / 'transit-client-0.0.1.jar', lib / 'gson-2.12.1.jar')))
        subprocess.run(['java', f'-Djava.io.tmpdir={target}', '-cp', raw_classpath, 'ArtifactCheck'], env=environment, cwd=target, check=True, timeout=20)
        bad = target / 'bad-native.jar'
        with zipfile.ZipFile(bad, 'w') as jar:
            jar.writestr('io/transit/nativeclient/version', '99.0.0\n')
            jar.writestr('io/transit/nativeclient/transit-client-host', b'not executable')
        subprocess.run(['java', f'-Djava.io.tmpdir={target}', '-cp', raw_classpath + os.pathsep + str(bad), 'ArtifactCheck'], env=environment, cwd=target, check=True, timeout=20)
        bad.unlink()
        startup = target / 'JavaNativeStartup.java'
        shutil.copy2(root / 'tests/sdk/consumers/java' / startup.name, startup)
        subprocess.run(['javac', '--release', '21', '-Xlint:all', '-Werror', '-cp', str(lib / '*'), '-d', str(classes), str(startup)], env=environment, cwd=target, check=True)
        startup.unlink()
        blocked_tmp = target / 'not-a-directory'
        blocked_tmp.write_text('fixture')
        broken_host = target / 'broken-native'
        broken_host.write_text('#!/missing-transit-java-test-interpreter\n')
        broken_host.chmod(0o700)
        classpath = os.pathsep.join((str(classes), str(lib / '*')))
        for phase, temporary, override in (
            ('native-artifact', blocked_tmp, []),
            ('native-start', blocked_tmp, [str(broken_host)]),
            ('native-start', target, [str(broken_host)]),
        ):
            subprocess.run(['java', f'-Djava.io.tmpdir={temporary}', '-cp', classpath,
                            'JavaNativeStartup', phase, *override], env=environment, cwd=target, check=True, timeout=20)
            assert not list(target.glob('transit-java-*')), 'Failed startup leaked native/configuration files'
        blocked_tmp.unlink(); broken_host.unlink()
        bodies = {
            'bad-version': 'print(\'{"status":0,"value":{"host_version":99,"transit_version":1}}\')',
            'fractional-version': 'print(\'{"status":0,"value":{"host_version":1.0000000000000001,"transit_version":1}}\')',
            'bad-status': 'print(\'{"status":99,"value":null}\')',
            'fractional-status': 'print(\'{"status":0.0000000000000001,"value":null}\')',
            'huge-status': 'print(\'{"status":1e999999999,"value":null}\')',
            'bad-utf8': 'sys.stdout.buffer.write(b"\\xff\\n")',
            'bad-duplicate': 'print(\'{"status":0,"status":0,"value":null}\')',
            'bad-oversize': 'sys.stdout.write("x" * 540673)',
            'bad-partial': 'sys.stdout.write("{")',
        }
        for name, body in bodies.items():
            fake = target / name
            fake.write_text(f'#!{sys.executable}\nimport sys\nsys.stdin.readline()\n{body}\n')
            fake.chmod(0o700)
        def invoke(mode, config):
            return subprocess.check_output(['java', f'-Djava.io.tmpdir={target}', '-cp', os.pathsep.join((str(classes), str(lib / '*'))), 'JavaClientSdk', mode, str(config)],
                                           env=environment, cwd=target, timeout=40)
        return invoke
    schedule(node, cli, library, install, 'Java')


if __name__ == '__main__': run(*sys.argv[1:])
