#!/usr/bin/env python3
"""Real CLI failures: actionable coordinates, privacy, streams and no startup effects."""
import copy
import json
import os
import shutil
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
from console_settings import parse_show, read_show

CLI = str(Path(sys.argv[1]).resolve())
ENV = {key: value for key, value in os.environ.items() if not key.startswith('TRANSIT_')}
CASES = 0
ISOLATED = tempfile.TemporaryDirectory(prefix='transit-cli-environment-')
ENV['HOME'] = ISOLATED.name


def invoke(args, expected=2, contains=(), env=None, data=b'', stderr=None, cwd=None, binary=None):
    global CASES
    result = subprocess.run([binary or CLI, *map(str, args)], input=data, capture_output=True,
                            timeout=10, env=ENV if env is None else env, cwd=cwd or ISOLATED.name)
    assert result.returncode == expected, (args, result.returncode, result.stdout, result.stderr)
    if expected:
        assert result.stdout == b'', (args, result.stdout)
        prefix = b'Usage: ' if stderr is not None and stderr.startswith('Usage: ') else b'error: '
        assert result.stderr.startswith(prefix), (args, result.stderr)
        for label in (b'\n  at: ', b'\n  cause: ', b'\n  next: ', b'\n  help: '):
            assert label not in result.stderr, (args, label, result.stderr)
        assert b'private-must-not-appear' not in result.stderr, result.stderr
        assert b'\x1b' not in result.stderr and b'\r' not in result.stderr, result.stderr
        assert len(result.stderr) < 4096, (args, len(result.stderr))
    else:
        assert result.stderr == b'', result.stderr
    output = result.stderr if expected else result.stdout
    for fragment in contains:
        assert fragment.encode() in output, (args, fragment, output)
    if stderr is not None:
        assert result.stderr == stderr.encode(), (args, result.stderr, stderr)
    CASES += 1
    return result


for command in ('server', 'serve'):
    invoke([command], contains=('cannot find minio beside transit or on PATH',))
    for value in ([], ['--initialize'], ['']):
        invoke([command, '--config', *value], stderr='error: --config requires a file path\n')
    invoke([command, '--config', 'one', '--config', 'two'], stderr='error: --config can only be specified once\n')
    for flag in ('--initialize', '--no-ui', '--help'):
        invoke([command, flag, flag], stderr=f'error: {flag} can only be specified once\n')
    invoke([command, '--format', 'json'], contains=('--format is not supported', f'transit {command} --help'))
    invoke([command, '--unknown=private-must-not-appear'], contains=('unexpected input at argument 2',))
    invoke([command, '--help'], 0, ('Server configuration file (overrides discovery)', '--initialize', '--no-ui', 'Alias: serve'))
    invoke([command, '--config', 'private-must-not-appear', '--help'], 0)
for args in ([], ['--help'], ['--version'], ['app'], ['app', '--help'], ['console', '--help'], ['query', '--help'], ['query-v2', '--help']):
    invoke(args, 0)
root_help = invoke(['--help'], 0, ('Usage: transit COMMAND [OPTIONS]', 'Commands:', 'Options:')).stdout
assert b'--initialize' not in root_help and b'--config' not in root_help
invoke(['private-must-not-appear'], contains=('unknown command', 'argument 1', 'transit --help'))
invoke(['--help', 'extra'], contains=('argument 1',))
invoke(['console', '--no-rc'], contains=('cannot read the local installation', 'installation.json'))
invoke(['console', '--config', 'missing', '--format', 'csv'], stderr='error: --format must be table or json\n')
invoke(['console', '--format'], stderr='error: --format must be table or json\n')
invoke(['console', '--config', 'missing', '--no-ui'], contains=('--no-ui is not supported',))
for command in ('query', 'query-v2'):
    invoke([command], contains=('a configuration file is required', f'Usage: transit {command} CONFIG'))
    invoke([command, 'one', 'two'], contains=('argument 3',))
    invoke([command, '--config'], contains=('argument 2',))
invoke(['app', 'private-must-not-appear'], contains=('unknown application subcommand', 'argument 2'))
for mode in ('install', 'replace', 'retry', 'status', 'connect'):
    invoke(['app', mode], contains=(f'Usage: transit app {mode}', '--config is required'))
    invoke(['app', mode, '--config'], stderr='error: --config requires a file path\n')
    invoke(['app', mode, '--config', 'one', '--config', 'two'], stderr='error: --config can only be specified once\n')
    help_output = invoke(['app', mode, '--help'], 0, (f'Usage: transit app {mode}', 'Options:', '--config PATH', '--operation ID')).stdout
    assert (b'--file ' in help_output) == (mode in ('install', 'replace'))
    assert (b'--after ' in help_output) == (mode == 'status')
    assert (b'--caller ' in help_output) == (mode == 'connect')
    assert (b'--output ' in help_output) == (mode == 'connect')
    invoke(['app', mode, '--config', 'private-must-not-appear', '--help'], 0)
    invoke(['app', mode, '--help', '--help'], stderr='error: --help can only be specified once\n')
    invoke(['app', mode, '--help', '--unknown=private-must-not-appear'], contains=('argument 4',))
    invoke(['app', mode, '--help', '--config'], stderr='error: --config requires a file path\n')
invoke(['app', 'status', '--config', 'missing'], contains=('--application is required',))
invoke(['app', 'install', '--config', 'missing'], contains=('--file is required',))
invoke(['app', 'install', '--config', 'missing', '--file', 'missing'], contains=('--operation is required',))
invoke(['app', 'status', '--file', 'private-must-not-appear'], contains=('--file is not supported', 'transit app status --help'))
invoke(['app', 'status', '--after', '4294967296'], stderr='error: --after must be an integer from 0 through 4294967295\n')

with tempfile.TemporaryDirectory(prefix='transit-cli-diagnostics-') as directory:
    root = Path(directory)
    path = root / 'server.json'
    installation = root / 'installation'
    def server(config, contains, expected=2):
        path.write_text(json.dumps(config))
        return invoke(['server', '--config', path, '--no-ui'], expected, contains)

    for command in ('server', 'console'):
        invoke([command, '--config', root / 'missing.json'], contains=('configuration file', 'missing.json', 'was not found'))
    invoke(['app', 'status', '--config', root / 'missing.json', '--application', 'test'], contains=('configuration file', 'was not found'))
    for text, explanation in (('{\n  "version": !\n}', 'invalid JSON'), ('{"version":1,"version":1}', 'duplicate field'), ('{"private-must-not-appear":0}', 'unknown field')):
        path.write_text(text)
        invoke(['server', '--config', path], contains=(explanation, 'server.json'))
    path.write_text('{}')
    invoke(['server', '--config', path], contains=('cannot find minio beside transit or on PATH',))
    path.write_text('{\n  "version": !\n}')
    invoke(['server', '--config', path], contains=('server.json":2:14',))
    path.write_bytes(b' ' * 65537)
    invoke(['server', '--config', path], contains=('size limit',))
    invoke(['server', '--config', str(root / 'evil\x1b[31m\n.json')], contains=('\\x1b', '\\x0a'))
    invoke(['server', '--config', 'x' * 4096], contains=('...', 'cannot read configuration file'))

    config = {'version': 1, 'installation': str(installation), 'realm': 73,
              'ports': dict(zip(('cold', 'cold_console', 'store', 'node', 'gateway'), range(29001, 29006))),
              'executables': dict.fromkeys(('minio', 'ursula', 'node', 'query_host'), sys.executable)}
    missing = copy.deepcopy(config)
    del missing['ports']['gateway']
    server(dict(missing, realm=0), ('realm',))  # Missing gateway now inherits its default.
    for key, value, field in (('version', 4, 'version'), ('realm', 0, 'realm'), ('admission_ceiling', 127, 'admission_ceiling'), ('control_reserve', 65537, 'control_reserve'), ('gateway_allowed_hosts', ['private-must-not-appear'], 'gateway_allowed_hosts')):
        invalid = dict(config, **{key: value})
        server(invalid, (field,))
    invalid = copy.deepcopy(config)
    invalid['ports']['gateway'] = invalid['ports']['node']
    server(invalid, ('ports.gateway and ports.node must be different',))
    invalid['ports']['gateway'] = 80
    server(invalid, ('ports.gateway must be a port from 1024 through 65535',))
    invalid = copy.deepcopy(config)
    invalid['executables']['query_host'] = 'private-must-not-appear'
    server(invalid, ('executables.query_host', 'file not found'))
    empty = root / 'empty-executable'
    empty.touch(mode=0o700)
    invalid['executables']['query_host'] = str(empty)
    server(invalid, ('executables.query_host', 'InvalidExecutable'))
    server(dict(config, version=3, executables=dict(config['executables'], board='absent-board')), ('executables.board',))
    path.write_text(json.dumps(config))
    invoke(['server', '--config', path], contains=('version must be 3 to start Board', '--no-ui'))
    with socket.socket() as listener:
        listener.bind(('127.0.0.1', 0))
        listener.listen()
        port = listener.getsockname()[1]
        invalid = copy.deepcopy(config)
        invalid['ports']['cold'] = port
        server(invalid, ('cannot bind', 'ports.cold', 'address already in use', f'127.0.0.1:{port}'), 1)
    assert not installation.exists(), 'invalid invocation/configuration started provisioning'

    console = {'version': 1, 'profile': 'unified_v2', 'url': 'http://127.0.0.1:19105', 'transport': 'loopback',
               'seed_file': 'missing.seed', 'connection': dict(zip(('realm', 'principal', 'source', 'resource', 'requester', 'requests'), range(1, 7))),
               'workspace': {'name': 'items', 'source': {'resource': 4, 'source': {'table': {'id': 1, 'names': ['key', 'value'], 'value_type': 'int64'}}},
                             'limits': {'pages': '1', 'segments': '1', 'result_bytes': '65536'}}}
    path = root / 'console.json'
    for patch, field in (({'version': 2}, 'version'), ({'request_timeout_ms': 0}, 'request_timeout_ms'), ({'url': 'http://user:private-must-not-appear@127.0.0.1:19105'}, 'url / transport / ca_file')):
        path.write_text(json.dumps(dict(console, **patch)))
        invoke(['console', '--config', path, '--format', 'json'], contains=(field,))
    missing = copy.deepcopy(console)
    del missing['workspace']['source']['source']['table']['id']
    path.write_text(json.dumps(missing))
    invoke(['console', '--config', path], contains=('missing required field workspace.source.source.table.id',))
    path.write_text(json.dumps(dict(console, url='https://localhost:19105', transport='tls_ca', ca_file='missing.pem')))
    invoke(['console', '--config', path], contains=('ca_file', 'file not found', 'CA certificates'))
    path.write_text(json.dumps(console))
    invoke(['console', '--config', path], contains=('seed_file', 'file not found', 'signing credential'))
    invoke(['console'], contains=('seed_file',), env=dict(ENV, TRANSIT_CONSOLE_CONFIG=str(path)))
    invoke(['console', '--config', root/'override.json'], contains=('override.json',), env=dict(ENV, TRANSIT_CONSOLE_CONFIG=str(path)))
    invoke(['server'], contains=('cannot find minio beside transit or on PATH',), env=dict(ENV, TRANSIT_CONSOLE_CONFIG=str(path)))
    # The executable's physical directory precedes PATH, independent of cwd.
    adjacent, search = root/'bin', root/'search'
    adjacent.mkdir(); search.mkdir()
    local_cli = adjacent/'transit'
    shutil.copy2(CLI, local_cli)
    names = ('minio', 'ursula', 'transit-node', 'transit-query-host', 'transit-board')
    for name in names: (adjacent/name).symlink_to(sys.executable)
    discovery_config = root/'convention.json'
    reserved = [socket.socket() for _ in range(6)]
    for listener in reserved: listener.bind(('127.0.0.1', 0))
    ports = [listener.getsockname()[1] for listener in reserved]
    for listener in reserved: listener.close()
    discovery_config.write_text(json.dumps({'installation': str(root/'uninitialized'),
        'ports': dict(zip(('cold', 'cold_console', 'store', 'node', 'gateway'), ports)),
        'applications': {'port': ports[5]}}))
    def convention(**values):
        return invoke(['server', '--config', discovery_config, '--no-ui'], 1, ('retained installation record',),
                      env=dict(ENV, PATH=str(search), **values), cwd=root, binary=str(local_cli))
    convention()  # No manifest or tools on PATH.
    for name in names: (search/name).touch(mode=0o700)
    convention()  # Executable but invalid PATH files cannot shadow adjacent binaries.
    for name in names:
        (adjacent/name).unlink(); (search/name).unlink(); (search/name).symlink_to(sys.executable)
    convention()  # PATH fallback.
    # Explicit executable overrides win over both discovery locations.
    discovery_config.write_text(json.dumps({'executables': {'node': 'absent-node'}}))
    invoke(['server', '--config', discovery_config], contains=('executables.node',),
           env=dict(ENV, PATH=str(search)), cwd=root, binary=str(local_cli))

    # Real file selection, typed overlays, no fallback and rc precedence.
    home, project = root/'home', root/'project'
    home.mkdir(); project.mkdir()
    environment = dict(ENV, HOME=str(home))
    home_server, project_server = home/'transit.yaml', project/'transit.yaml'
    home_server.write_text('version: 9\n')
    invoke(['server'], env=environment, cwd=project, contains=('version', 'home/transit.yaml'))
    project_server.write_text('executables: 1\n')
    invoke(['server'], env=environment, cwd=project, contains=('executables must be an object', 'project/transit.yaml'))
    project_server.write_text('ports: !tag invalid\n')
    invoke(['server'], env=environment, cwd=project, contains=('unsupported YAML',))
    invoke(['server', '--config', home_server], env=environment, cwd=project, contains=('version', 'home/transit.yaml'))
    yaml_config = 'version: 1\nrealm: 0\nexecutables:\n'+''.join(f'  {key}: {sys.executable}\n' for key in ('minio', 'ursula', 'node', 'query_host'))
    project_server.write_text(yaml_config)
    invoke(['server', '--no-ui'], env=environment, cwd=project, contains=('realm must be',))
    for setting in ({'TRANSIT_BOGUS': 'private-must-not-appear'}, {'TRANSIT_PORTS__GATEWAY': '"private-must-not-appear"'}):
        invoke(['server', '--no-ui'], env=dict(environment, **setting), cwd=project,
               contains=('setting' if 'TRANSIT_BOGUS' in setting else 'ports.gateway',))
    # Deep leaves beat whole objects, preserve other default ports and validate conflicts.
    invoke(['server', '--no-ui'], env=dict(environment, TRANSIT_REALM='1', TRANSIT_PORTS='{"gateway":10000}', TRANSIT_PORTS__GATEWAY='19104'), cwd=project,
           contains=('ports.gateway and ports.node',))
    for content in ('x: '+ '['*20+'0'+']'*20, '{"x":'+ '['*20+'0'+']'*20+'}', 'ports: &anchor 1', 'realm: 1\nrealm: 2'):
        project_server.write_text(content)
        invoke(['server'], env=environment, cwd=project)
    project_server.unlink()
    invoke(['server', '--config', project/'absent.yaml'], env=environment, cwd=project, contains=('absent.yaml', 'was not found'))

    connection = project/'console.yaml'
    (project/'caller.key').write_text('11'*32)
    connection.write_text('\n'.join(f'{key}: {json.dumps(value)}' for key, value in dict(console, seed_file='caller.key').items()))
    (home/'.transitrc').write_text('.connect missing.json\n.mode json\n')
    (project/'.transitrc').write_text('.connect console.yaml\n')
    shown = invoke(['console'], 0, env=environment, cwd=project, data=b'.show\n')
    settings = parse_show(shown.stdout)
    assert settings['connection'] == str(connection) and settings['format'] == 'json'
    assert settings['connection_source'] == str(project/'.transitrc')
    assert settings['format_source'] == str(home/'.transitrc')
    (project/'.transitrc').write_text('.connect console.yaml\n.mode table\n')
    settings = parse_show(invoke(['console'], 0, env=environment, cwd=project, data=b'.show\n').stdout)
    assert settings['format'] == 'table'
    assert settings['format_source'] == str(project/'.transitrc')
    settings = parse_show(invoke(['console', '--format', 'json'], 0, env=environment, cwd=project, data=b'.show\n').stdout)
    assert settings['format'] == 'json' and settings['format_source'] == '--format'
    invoke(['console'], env=dict(environment, TRANSIT_CONSOLE_CONFIG='absent.json'), cwd=project, contains=('absent.json',))
    shown = invoke(['console', '--config', connection], 0, env=dict(environment, TRANSIT_CONSOLE_CONFIG='absent.json'), cwd=project, data=b'.show\n')
    assert parse_show(shown.stdout)['connection_source'] == '--config'
    shown = invoke(['console'], 0, env=dict(environment, TRANSIT_CONSOLE_CONFIG=str(connection)), cwd=project, data=b'.show\n')
    assert parse_show(shown.stdout)['connection_source'] == 'TRANSIT_CONSOLE_CONFIG'
    (home/'.transitrc').write_text('.timing off\n')
    (project/'.transitrc').write_text('.timing on\n')
    shown = invoke(['console', '--config', connection], 0, env=environment, cwd=project, data=b'.show\n')
    settings = parse_show(shown.stdout)
    assert settings['timing'] == 'on' and settings['timing_source'] == str(project/'.transitrc')
    shown = invoke(['console', '--config', connection], 0, env=environment, cwd=project, data=b'.timing off\n.show\n')
    settings = parse_show(shown.stdout)
    assert settings['timing'] == 'off' and settings['timing_source'] == '.timing'
    for format in ('table', 'json'):
        for text in (b'.timing\n', b'.timing \t\n', b'.timing private-must-not-appear\n', b'.timing on off\n'):
            invoke(['console', '--no-rc', '--config', connection, '--format', format], 1,
                   env=environment, cwd=project, data=text+b'.show\n', stderr='Usage: .timing on|off\n')
    shown = invoke(['console', '--no-rc', '--config', connection], 0, env=environment, cwd=project,
                   data=b'.timing\ton\n.show\n')
    assert parse_show(shown.stdout)['timing'] == 'on'
    # Local settings need no server. Real terminals keep the setting and prompt
    # after usage errors, with no status JSON accidentally left on stdout.
    from console_terminal import Terminal
    for format in ('table', 'json'):
        terminal = Terminal(CLI, connection, format=format, cwd=project)
        try:
            terminal.send('.timing on\r')
            terminal.expect('transit> .timing on\r\n')
            for text in ('.timing', '.timing off on'):
                terminal.send(text+'\r')
                terminal.expect('Usage: .timing on|off\r\n')
                terminal.send('.show\r')
                settings = read_show(terminal)
                assert settings['timing'] == 'on' and settings['format'] == format, settings
            terminal.send('.timing off\r')
            terminal.expect('transit> .timing off\r\n')
            terminal.send('.show\r')
            assert read_show(terminal)['timing'] == 'off'
        finally:
            terminal.close()
        CASES += 1
    (project/'.transitrc').write_text('.timing invalid\n')
    invoke(['console', '--config', connection], env=environment, cwd=project, contains=('.timing must be on or off',))
    (project/'.transitrc').write_text('SELECT private-must-not-appear;\n')
    invoke(['console', '--config', connection], env=environment, cwd=project, contains=('startup command',))
    shown = invoke(['console', '--no-rc', '--config', connection], 0, env=environment, cwd=project, data=b'.show\n')
    assert parse_show(shown.stdout)['format_source'] == 'connection configuration'
    chosen = home/'custom.rc'; chosen.write_text(f'.connect {connection}\n.mode json\n')
    shown = invoke(['console', '--init', chosen], 0, env=environment, cwd=project, data=b'.show\n')
    assert parse_show(shown.stdout)['format_source'] == str(chosen)
    assert parse_show(shown.stdout)['connection_source'] == str(chosen)
    shown = invoke(['console', '--no-rc', '--config', connection, '--format', 'json'], 0,
                   env=environment, cwd=project, data=b'.mode table\n.show\n')
    assert parse_show(shown.stdout)['format'] == 'table'
    assert parse_show(shown.stdout)['format_source'] == '.mode'
    escaped_connection = project/'control\n\r\t\x1b\\".yaml'
    escaped_connection.write_bytes(connection.read_bytes())
    shown = invoke(['console', '--no-rc', '--config', escaped_connection], 0,
                   env=environment, cwd=project, data=b'.show\n')
    assert parse_show(shown.stdout)['connection'] == json.dumps(str(escaped_connection))[1:-1]
    for arguments in (['-c', 'select 1', '-f', 'x'], ['--init', chosen, '--no-rc'], ['-c'], ['-f'], ['-c', '-f']):
        invoke(['console', *arguments], env=environment, cwd=project)
    local = project/'.transit'; local.mkdir()
    (local/'caller.seed').write_text('11'*32)
    (project/'.transitrc').unlink(); (home/'.transitrc').unlink(); home_server.unlink()
    identity = dict.fromkeys(('config', 'cli', 'minio', 'ursula', 'node', 'query_host'), [0]*32)
    record = dict(identity=identity, installation=[0]*16, root_public=[0]*32,
                  complete=True, genesis_observed=True, provision=list(range(1, 15)))
    (local/'installation.json').write_text(json.dumps(record))
    shown = invoke(['console'], 0, env=environment, cwd=project, data=b'.show\n')
    settings = parse_show(shown.stdout)
    assert settings['connection'] == '(automatic)' and settings['connection_source'] == 'local installation'
    assert settings['url'] == 'http://127.0.0.1:19105'
    assert not (local/'console.json').exists() and not (local/'console.yaml').exists()
    (home/'.transitrc').write_text('.mode json\n')
    shown = invoke(['console'], 0, env=environment, cwd=project, data=b'.show\n')
    assert parse_show(shown.stdout)['format'] == 'json'
    project_server.write_text('ports:\n  gateway: 29305\n')
    shown = invoke(['console'], 0, env=environment, cwd=project, data=b'.show\n')
    assert parse_show(shown.stdout)['url'] == 'http://127.0.0.1:29305'
    shown = invoke(['console'], 0, env=dict(environment, TRANSIT_PORTS__GATEWAY='29306'), cwd=project, data=b'.show\n')
    assert parse_show(shown.stdout)['url'] == 'http://127.0.0.1:29306'
    record['complete'] = False
    (local/'installation.json').write_text(json.dumps(record))
    invoke(['console'], env=environment, cwd=project, contains=('is not initialized',))
    # Leading SQL comments are values, not CLI flags.
    invoke(['console', '--no-rc', '--config', connection, '-c', '-- comment\nSELECT COUNT(*) FROM items'], 1,
           env=environment, cwd=project, contains=('recovery_file',))
    assert not installation.exists()
print(f'CLI diagnostics passed: {CASES} real command cases; no configuration or credential disclosure, stdout contamination or provisioning.')
