#!/usr/bin/env python3
"""Real CLI failures: actionable coordinates, privacy, streams and no startup effects."""
from runner.paths import ROOT
import copy
import atexit
from interfaces.sql_sessions.editor_peer import peer as session_peer
import json
import os
import re
import select
import shutil
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
from interfaces.cli.console_settings import parse_show, read_show

CLI = str(Path(sys.argv[1]).resolve())
# Configuration discovery is controlled by the fixture's HOME and explicit
# overrides below, including XDG precedence. Ambient XDG must not bypass HOME.
ENV = {key: value for key, value in os.environ.items()
       if not key.startswith('TRANSIT_') and key != 'XDG_CONFIG_HOME'}
CASES = 0
SESSION_PEER = session_peer(structured=True)
SQL_ENDPOINT, SESSION_ACTIONS = SESSION_PEER.__enter__()
atexit.register(SESSION_PEER.__exit__, None, None, None)
ISOLATED = tempfile.TemporaryDirectory(prefix='transit-cli-environment-')
ENV['HOME'] = ISOLATED.name
# Dependency absence is a controlled fixture, independent of developer tools.
NO_TOOLS = Path(ISOLATED.name) / 'no-tools'
NO_TOOLS.mkdir()
ISOLATED_CLI = NO_TOOLS / 'transit'
shutil.copy2(CLI, ISOLATED_CLI)


def invoke(args, expected=2, contains=(), env=None, data=b'', stderr=None, cwd=None, binary=None, stdout_contains=()):
    global CASES
    result = subprocess.run([binary or CLI, *map(str, args)], input=data, capture_output=True,
                            timeout=10, env=ENV if env is None else env, cwd=cwd or ISOLATED.name)
    assert result.returncode == expected, (args, result.returncode, result.stdout, result.stderr)
    if expected:
        if stdout_contains:
            for fragment in stdout_contains:
                assert fragment.encode() in result.stdout, (args, result.stdout)
        else:
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


for command in ('server',):
    invoke([command], contains=('cannot find transit-node beside transit or on PATH',),
           env=ENV | {'PATH': str(NO_TOOLS)}, binary=str(ISOLATED_CLI))
    for value in ([], ['--initialize'], ['']):
        invoke([command, '--config', *value], stderr='error: --config requires a file path\n')
    invoke([command, '--config', 'one', '--config', 'two'], stderr='error: --config can only be specified once\n')
    for flag in ('--no-ui', '--help'):
        invoke([command, flag, flag], stderr=f'error: {flag} can only be specified once\n')
    invoke([command, '--format', 'json'], contains=('--format is not supported', f'transit {command} --help'))
    invoke([command, '--unknown=private-must-not-appear'], contains=('unexpected input at argument 2',))
    invoke([command, '--initialize'], contains=('unexpected input at argument 2',))
    help_output = invoke([command, '--help'], 0, ('Server configuration file (overrides discovery)', 'startup.require_existing', '--no-ui')).stdout
    assert b'--initialize' not in help_output
    invoke([command, '--config', 'private-must-not-appear', '--help'], 0)
for args in ([], ['--help'], ['--version'], ['console', '--help']):
    invoke(args, 0)
root_help = invoke(['--help'], 0, ('Usage: transit COMMAND [OPTIONS]', 'Commands:', 'Options:')).stdout
assert b'--initialize' not in root_help and b'--config' not in root_help
commands = root_help.split(b'Commands:\n', 1)[1].split(b'\nOptions:', 1)[0]
assert [line.split()[0] for line in commands.splitlines() if line.strip()] == [b'server', b'console']
invoke(['private-must-not-appear'], contains=('unknown command', 'argument 1', 'transit --help'))
invoke(['--help', 'extra'], contains=('argument 1',))
invoke(['console', '--no-rc'], 1, contains=('local SQL',))
invoke(['console', '--config', 'missing', '--format', 'csv'], stderr='error: --format must be table or json\n')
invoke(['console', '--format'], stderr='error: --format must be table or json\n')
invoke(['console', '--config', 'missing', '--no-ui'], contains=('--no-ui is not supported',))
invoke(['console', '--parameters', 'bindings.json'], contains=('--parameters requires -c SQL',))
invoke(['console', '-f', 'script.sql', '--parameters', 'bindings.json'], contains=('--parameters requires -c SQL',))
invoke(['console', '-c', 'SELECT * FROM items', '--parameters'], contains=('--parameters requires a file path',))
invoke(['console', '-c', 'SELECT * FROM items', '--parameters', 'one', '--parameters', 'two'], contains=('--parameters can only be specified once',))
invoke(['server', '--parameters', 'bindings.json'], contains=('--parameters is not supported',))
invoke(['console', '--help'], 0, ('--parameters FILE', '.execute FILE'))
parameter_file = Path(ISOLATED.name) / 'parameters.json'
for invalid in ('null', '{}', '[{"utf8": "private-must-not-appear", "unsigned":"1"}]',
                '[{"unsigned":1}]', json.dumps([{'boolean': True}] * 66),
                ' ' * 131073):
    parameter_file.write_text(invalid)
    invoke(['console', '--no-rc', '--config', 'missing-connection', '--parameters', parameter_file,
            '-c', 'SELECT * FROM items LIMIT $1'], contains=('cannot read SQL parameter input',))
with tempfile.TemporaryDirectory(prefix='transit-cli-diagnostics-') as directory:
    root = Path(directory)
    path = root / 'server.json'
    installation = root / 'installation'
    def server(config, contains, expected=2):
        path.write_text(json.dumps(config))
        return invoke(['server', '--config', path, '--no-ui'], expected, contains)

    for command in ('server', 'console'):
        invoke([command, '--config', root / 'missing.json'], contains=('configuration file', 'missing.json', 'was not found'))
    assert not (root / 'must-not-exist.json').exists()
    # Malformed artifacts fail before the missing key could be loaded.
    for text, explanation in (('{\n  "version": !\n}', 'invalid JSON'), ('{"version":1,"version":1}', 'duplicate field'), ('{"private-must-not-appear":0}', 'unknown field')):
        path.write_text(text)
        invoke(['server', '--config', path], contains=(explanation, 'server.json'))
    path.write_text('{}')
    invoke(['server', '--config', path], contains=('cannot find transit-node beside transit or on PATH',),
           env=ENV | {'PATH': str(NO_TOOLS)}, binary=str(ISOLATED_CLI))
    path.write_text('{\n  "version": !\n}')
    invoke(['server', '--config', path], contains=('server.json":2:14',))
    path.write_bytes(b' ' * 65537)
    invoke(['server', '--config', path], contains=('size limit',))
    invoke(['server', '--config', str(root / 'evil\x1b[31m\n.json')], contains=('\\x1b', '\\x0a'))
    invoke(['server', '--config', 'x' * 4096], contains=('...', 'cannot read configuration file'))

    config = {'version': 1, 'installation': str(installation), 'realm': 73,
              'ports': dict(zip(('node', 'gateway'), range(29004, 29006))),
              'executables': dict.fromkeys(('node', 'query_host', 'board', 'sql_gateway'), sys.executable)}
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
    server(dict(config, executables=dict(config['executables'], board='absent-board')), ('executables.board',))
    server(dict(config, executables=dict(config['executables'], sql_gateway='absent-sql')), ('executables.sql_gateway',))
    for sql, expected in [
        ({'postgres': {'port': 80}}, 'sql.postgres.port'),
        ({'postgres': {'port': 29004}}, 'sql.postgres.port'),
        ({'postgres': {}, 'mysql': {'port': 15432}}, 'sql.mysql.port'),
        ({'command_ms': 270001}, 'sql.command_ms'),
        ({'tls': {'key_file': 'private-must-not-appear'}}, 'sql.tls'),
        ({'accounts': [{'name': '../escape', 'role': 'reader', 'password_file': 'private'}]}, 'sql.accounts'),
        ({'accounts': [{'name': 'reader', 'role': 'reader', 'password_file': 'private', 'database': 'unknown'}]}, 'sql.accounts'),
    ]:
        if 'postgres' in sql or 'mysql' in sql:
            sql.setdefault('accounts', [dict(name='owner', role='local_owner', authentication='trust')])
        server(dict(config, sql=sql), (expected,))
    for sql, expected in [
        ({'postgres': {}, 'accounts': []}, 'sql.accounts'),
        ({'mysql': {}, 'accounts': [dict(name='off', role='local_owner', authentication='trust', enabled=False)]}, 'sql.accounts'),
        ({'tls': {'mode': 'unsafe'}}, 'sql.tls.mode'),
        ({'tls': {'mode': 'disabled', 'certificate_file': 'private', 'key_file': 'private', 'ca_file': 'private'}}, 'sql.tls'),
        ({'accounts': [dict(name='owner', role='local_owner')]}, 'sql.accounts'),
        ({'accounts': [dict(name='owner', role='local_owner', authentication='trust', password_file='private')]}, 'sql.accounts'),
        ({'accounts': [dict(name='owner', role='reader', authentication='trust', bootstrap_owner=True)]}, 'sql.accounts'),
        ({'mysql': {}, 'tls': {'mode': 'disabled'}, 'accounts': [dict(name='owner', role='local_owner', password_file='private')]}, 'sql.tls.mode'),
    ]:
        server(dict(config, sql=sql), (expected,))
    server(dict(config, version=2), ('version must be 1',))
    server(dict(config, version=3), ('version must be 1',))
    with socket.socket() as listener:
        listener.bind(('127.0.0.1', 0))
        listener.listen()
        port = listener.getsockname()[1]
        invalid = copy.deepcopy(config)
        invalid['ports']['node'] = port
        server(invalid, ('cannot bind', 'ports.node', 'address already in use', f'127.0.0.1:{port}'), 1)
        for protocol in ('postgres', 'mysql'):
            server(dict(config, sql={protocol: {'port': port}, 'accounts': [dict(name='owner', role='local_owner', authentication='trust')]}), ('cannot bind', f'sql.{protocol}.port', 'address already in use'), 1)
    assert not installation.exists(), 'invalid invocation/configuration started provisioning'

    # Client-file validation and server-diagnostic forwarding. The peer is an
    # explicit rendering fixture; real compilation is tested by sql-sessions.
    console = dict(version=1, endpoint=SQL_ENDPOINT, authentication='trust')
    path = root / 'console.json'
    for patch, field in (({'version': 2}, 'version'), ({'request_timeout_ms': 0}, 'request_timeout_ms'),
                         ({'endpoint': 'http://user:private-must-not-appear@127.0.0.1:1'}, 'endpoint'),
                         ({'recovery_file': 'old.json'}, 'unknown field'),
                         ({'catalog': {}}, 'unknown field'), ({'seed_file': 'old.seed'}, 'unknown field'),
                         ({'execution': 'captured'}, 'unknown field'), ({'execution': 'interactive'}, 'unknown field')):
        path.write_text(json.dumps(dict(console, **patch)))
        invoke(['console', '--no-rc', '--config', path], contains=(field,))
    path.write_text(json.dumps(dict(console, endpoint='https://localhost:19109', authentication='scram', ca_file='missing.pem')))
    invoke(['console', '--config', path], contains=('ca_file', 'file not found', 'CA certificates'))
    path.write_text(json.dumps(console))
    shown = invoke(['console'], 0, env=dict(ENV, TRANSIT_CONSOLE_CONFIG=str(path)), data=b'.show\n')
    assert parse_show(shown.stdout)['endpoint'] == SQL_ENDPOINT
    invoke(['console', '--config', root/'override.json'], contains=('override.json',), env=dict(ENV, TRANSIT_CONSOLE_CONFIG=str(path)))
    invoke(['server'], contains=('cannot find transit-node beside transit or on PATH',),
           env=dict(ENV, PATH=str(NO_TOOLS), TRANSIT_CONSOLE_CONFIG=str(path)), binary=str(ISOLATED_CLI))
    invoke(['console', '--no-rc', '--config', path, '-c', 'SELECT typo FROM items'], 1, ('Unknown column',))
    for data in (b"SELECT * FROM items WHERE value = 'private-must-not-appear", b'SELECT * /* private-must-not-appear'):
        before = len(SESSION_ACTIONS)
        invoke(['console', '--no-rc', '--config', path], 1, ('SQL parse error',), data=data)
        assert all(action != 'execute' for action, _ in SESSION_ACTIONS[before:]), 'Unclosed batch input reached SQL execution'
    invoke(['console', '--no-rc', '--config', path], 1, ('4096-byte statement limit',), data=b'SELECT '+b'x'*4096)
    # The executable's physical directory precedes PATH, independent of cwd.
    adjacent, search = root/'bin', root/'search'
    adjacent.mkdir(); search.mkdir()
    local_cli = adjacent/'transit'
    shutil.copy2(CLI, local_cli)
    names = ('transit-node', 'transit-query-host', 'transit-board', 'transit-sql-gateway')
    for name in names: (adjacent/name).symlink_to(sys.executable)
    discovery_config = root/'convention.json'
    reserved = [socket.socket() for _ in range(6)]
    for listener in reserved: listener.bind(('127.0.0.1', 0))
    ports = [listener.getsockname()[1] for listener in reserved]
    for listener in reserved: listener.close()
    discovery_config.write_text(json.dumps({'installation': str(root/'uninitialized'),
        'startup': {'require_existing': True},
        'ports': dict(zip(('node', 'gateway'), ports)),
        'applications': {'port': ports[5]}}))
    def convention(**values):
        return invoke(['server', '--config', discovery_config, '--no-ui'], 1, ('startup requires an existing installation',),
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
    (home/'.config').mkdir()
    home_server, project_server = home/'.config/transit.yaml', project/'transit.yaml'
    home_server.write_text('version: 9\n')
    invoke(['server'], env=environment, cwd=project, contains=('version', 'home/.config/transit.yaml'))
    project_server.write_text('executables: 1\n')
    invoke(['server'], env=environment, cwd=project, contains=('executables must be an object', 'project/transit.yaml'))
    project_server.write_text('ports: !tag invalid\n')
    invoke(['server'], env=environment, cwd=project, contains=('unsupported YAML',))
    invoke(['server', '--config', home_server], env=environment, cwd=project, contains=('version', 'home/.config/transit.yaml'))
    # Explicit environment selection and XDG directory override discovery.
    invoke(['server'], env=dict(environment, TRANSIT_CONFIG=str(home_server)), cwd=project,
           contains=('version', 'home/.config/transit.yaml'))
    invoke(['server', '--config', home_server], env=dict(environment, TRANSIT_CONFIG=str(project/'absent.yaml')),
           cwd=project, contains=('version', 'home/.config/transit.yaml'))
    project_server.unlink()
    xdg = root/'xdg'; xdg.mkdir()
    (xdg/'transit.yaml').write_text('version: 8\n')
    invoke(['server'], env=dict(environment, XDG_CONFIG_HOME=str(xdg)), cwd=project,
           contains=('version', 'xdg/transit.yaml'))
    invoke(['server'], env=dict(environment, TRANSIT_CONFIG=str(project/'absent.yaml')), cwd=project,
           contains=('absent.yaml', 'was not found'))
    yaml_config = 'version: 1\nrealm: 0\nexecutables:\n'+''.join(f'  {key}: {sys.executable}\n' for key in ('node', 'query_host', 'board', 'sql_gateway'))
    project_server.write_text(yaml_config)
    invoke(['server', '--no-ui'], env=environment, cwd=project, contains=('realm must be',))
    # Installed runtime loading must coexist with the repository's supported
    # build/launcher environment, while the invalid realm remains diagnosed.
    tools_environment = {name: 'private-must-not-appear' for name in (
        'TRANSIT_SQL_TOOLS', 'TRANSIT_GSON_JAR', 'TRANSIT_FUZE_BENCH_PYTHON',
        'TRANSIT_DOCS_BASE_URL', 'TRANSIT_DOCS_URL', 'TRANSIT_LIBRARY_DIR', 'TRANSIT_PORT',
        'TRANSIT_KUBECONFIG', 'TRANSIT_LAUNCHER_NAME', 'TRANSIT_LAUNCHER_BASE_PORT',
        'TRANSIT_BOARD_HOST', 'TRANSIT_BOARD_PORT', 'TRANSIT_BOARD_PUBLIC_ORIGIN',
        'TRANSIT_BOARD_ALLOW_INSECURE_HTTP', 'TRANSIT_LOG_LEVEL', 'TRANSIT_LOG_FORMAT',
        'TRANSIT_NODE_LOG_LEVEL', 'TRANSIT_STATION_OBSERVER_LOG_FORMAT')}
    invoke(['server', '--no-ui'], env=dict(environment, **tools_environment),
           cwd=project, contains=('realm must be',))
    for setting in ({'TRANSIT_BOGUS': 'private-must-not-appear'}, {'TRANSIT_PORTS__GATEWAY': '"private-must-not-appear"'}):
        invoke(['server', '--no-ui'], env=dict(environment, **setting), cwd=project,
               contains=('setting' if 'TRANSIT_BOGUS' in setting else 'ports.gateway',))
    for name in ('TRANSIT_BOARD_POTR', 'TRANSIT_NODE_LOG_LEVLE', 'TRANSIT_LAUNCHER_UNKNOWN'):
        invoke(['server', '--no-ui'], env=dict(environment, **{name: 'private-must-not-appear'}),
               cwd=project, contains=('setting',))
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
    connection.write_text('\n'.join(f'{key}: {json.dumps(value)}' for key, value in console.items()))
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
    (home/'.transitrc').write_text('.timer off\n')
    (project/'.transitrc').write_text('.timer on\n')
    shown = invoke(['console', '--config', connection], 0, env=environment, cwd=project, data=b'.show\n')
    settings = parse_show(shown.stdout)
    assert settings['timing'] == 'on' and settings['timing_source'] == str(project/'.transitrc')
    shown = invoke(['console', '--config', connection], 0, env=environment, cwd=project, data=b'.timer off\n.show\n')
    settings = parse_show(shown.stdout)
    assert settings['timing'] == 'off' and settings['timing_source'] == '.timer'
    for format in ('table', 'json'):
        for text in (b'.timer\n', b'.timer \t\n', b'.timer private-must-not-appear\n', b'.timer on off\n'):
            invoke(['console', '--no-rc', '--config', connection, '--format', format], 1,
                   env=environment, cwd=project, data=text+b'.show\n', stderr='Usage: .timer on|off\nInput: "<stdin>"; statement 1 starts at byte 0, line 1, byte column 1.\nPreviously completed commands: 0; their effects are not rolled back by this failure.\n')
    shown = invoke(['console', '--no-rc', '--config', connection], 0, env=environment, cwd=project,
                   data=b'.timer\ton\n.show\n')
    assert parse_show(shown.stdout)['timing'] == 'on'
    # Both early declaration validation and query compilation report timing
    # after the entire diagnostic, in one-shot and streamed batch input.
    timed_errors = (
        ('CREATE TABLE people (id INT64, name BINARY);', 'Unknown column'),
        ('SELECT;', 'Unknown column'),
    )
    for format in ('table', 'json'):
        for statement, hint in timed_errors:
            for one_shot in (False, True):
                result = invoke(['console', '--config', connection, '--format', format,
                                 *(['-c', statement] if one_shot else [])], 1,
                                contains=(hint,), env=environment, cwd=project,
                                data=b'' if one_shot else statement.encode())
                assert result.stderr.count(b'Time: ') == 1, result.stderr
                assert result.stderr.splitlines()[-1].startswith(b'Time: '), result.stderr
    # Local settings need no server. Real terminals keep the setting and prompt
    # after usage errors, with no status JSON accidentally left on stdout.
    from interfaces.cli.console_terminal import ANSI, Terminal
    for format in ('table', 'json'):
        terminal = Terminal(CLI, connection, format=format, cwd=project)
        try:
            terminal.send('.timer on\r')
            terminal.expect('transit> .timer on\r\n')
            for statement, hint in timed_errors:
                terminal.send(statement+'\r')
                terminal.expect(hint)
                terminal.expect('ms)\r\n')
                display = ANSI.sub(b'', terminal.screen)
                assert display.count(b'Time: ') == 1, display
                assert display.index(b'error: ') < display.index(hint.encode()) < display.index(b'Time: '), display
            for text in ('.timer', '.timer off on'):
                terminal.send(text+'\r')
                terminal.expect('Usage: .timer on|off\r\n')
                terminal.send('.show\r')
                settings = read_show(terminal)
                assert settings['timing'] == 'on' and settings['format'] == format, settings
                assert b'Time: ' not in terminal.screen, terminal.screen
            terminal.send('.timer off\r')
            terminal.expect('transit> .timer off\r\n')
            terminal.send('.show\r')
            assert read_show(terminal)['timing'] == 'off'
        finally:
            terminal.close()
        CASES += 1
    # Draft highlighting stays local. Result/diagnostic transport adds no
    # terminal escapes to redirected output; editor history has its own proof.
    for color_env, colored in (({'TERM':'xterm-256color','NO_COLOR':''}, True),
                               ({'TERM':'xterm-256color','NO_COLOR':'1'}, False),
                               ({'TERM':'dumb','NO_COLOR':''}, False)):
        terminal = Terminal(CLI, connection, cwd=project, env=color_env)
        try:
            before = len(SESSION_ACTIONS)
            terminal.send("SELECT /* comment */ 'literal', 12")
            terminal.expect('literal')
            assert (b'\x1b[36mSELECT' in terminal.screen) == colored, terminal.screen
            assert all(action != 'execute' for action, _ in SESSION_ACTIONS[before:])
            terminal.send('\x03')
            terminal.expect('transit> ')
        finally:
            terminal.close()
        CASES += 1
    # Color forcing inherited from a build runner must not decorate redirected
    # diagnostics or either machine result format.
    for format in ('table', 'json'):
        result = invoke(['console', '--config', connection, '--format', format, '-c', 'SELECT;'], 1,
                        env=dict(environment, TERM='xterm-256color', NO_COLOR='', CLICOLOR_FORCE='1'), cwd=project)
        assert b'\x1b' not in result.stderr and b'\x1b' not in result.stdout, result
    (project/'.transitrc').write_text('.timer invalid\n')
    invoke(['console', '--config', connection], env=environment, cwd=project, contains=('.timer must be on or off',))
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
    # A forged private installation record cannot supply console credentials.
    # Actual rendezvous/peer discovery is exercised by the installed server proof.
    local = project/'.transit'; local.mkdir()
    (local/'installation.json').write_text('{"complete":true}')
    (project/'.transitrc').unlink(); (home/'.transitrc').unlink(); home_server.unlink()
    invoke(['console'], 1, env=environment, cwd=project, contains=('local SQL',))
    assert (local/'installation.json').read_text() == '{"complete":true}'
    definition = json.loads((ROOT / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition']
    # Leading SQL comments are values, not CLI flags.
    invoke(['console', '--no-rc', '--config', connection, '-c', '-- comment\nSELECT COUNT(*) FROM items'], 1,
           env=environment, cwd=project, contains=('Unknown column',))
    assert not installation.exists()

for removed in ('app', 'auth', 'catalog', 'file-query', 'query', 'serve', 'mutate'):
    for suffix in ([], ['--help'], ['--config', 'private-must-not-appear']):
        invoke([removed, *suffix], contains=('unknown command', 'argument 1'))
    assert not re.search(rb'^  ' + removed.encode() + rb'\s', root_help, re.M)
for flag in ('--diagnostics=json', '--diagnostics', '--diagnostics=human'):
    invoke([flag, 'console', '--help'], contains=('argument 1',))
    for command in ('server', 'console'):
        invoke([command, flag], contains=('argument 2',))
    assert flag.encode() not in root_help
print(f'CLI diagnostics passed: {CASES} server/console cases, removed routes rejected before effects.')
