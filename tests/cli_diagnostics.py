#!/usr/bin/env python3
"""Real CLI failures: actionable coordinates, privacy, streams and no startup effects."""
import copy
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile

CLI = str(Path(sys.argv[1]).resolve())
ENV = {key: value for key, value in os.environ.items() if key != 'TRANSIT_CONSOLE_CONFIG'}
CASES = 0


def invoke(args, expected=2, contains=(), env=None, data=b'', stderr=None):
    global CASES
    result = subprocess.run([CLI, *map(str, args)], input=data, capture_output=True,
                            timeout=10, env=ENV if env is None else env)
    assert result.returncode == expected, (args, result.returncode, result.stdout, result.stderr)
    if expected:
        assert result.stdout == b'', (args, result.stdout)
        assert result.stderr.startswith(b'error: '), (args, result.stderr)
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
    invoke([command], stderr=f'error: --config is required\n\nUsage: transit {command} --config PATH\n')
    for value in ([], ['--initialize'], ['']):
        invoke([command, '--config', *value], stderr='error: --config requires a file path\n')
    invoke([command, '--config', 'one', '--config', 'two'], stderr='error: --config can only be specified once\n')
    for flag in ('--initialize', '--no-ui', '--help'):
        invoke([command, flag, flag], stderr=f'error: {flag} can only be specified once\n')
    invoke([command, '--format', 'json'], contains=('--format is not supported', f'transit {command} --help'))
    invoke([command, '--unknown=private-must-not-appear'], contains=('unexpected input at argument 2',))
    invoke([command, '--help'], 0, ('Server configuration file (required)', '--initialize', '--no-ui', 'Alias: serve'))
    invoke([command, '--config', 'private-must-not-appear', '--help'], 0)
for args in ([], ['--help'], ['--version'], ['app'], ['app', '--help'], ['console', '--help'], ['query', '--help'], ['query-v2', '--help']):
    invoke(args, 0)
root_help = invoke(['--help'], 0, ('Usage: transit COMMAND [OPTIONS]', 'Commands:', 'Options:')).stdout
assert b'--initialize' not in root_help and b'--config' not in root_help
invoke(['private-must-not-appear'], contains=('unknown command', 'argument 1', 'transit --help'))
invoke(['--help', 'extra'], contains=('argument 1',))
invoke(['console'], contains=('TRANSIT_CONSOLE_CONFIG', '--config'))
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
    for text, explanation in (('{\n  "version": !\n}', 'invalid JSON'), ('{"version":1,"version":1}', 'duplicate field'), ('{"private-must-not-appear":0}', 'unknown field'), ('{}', 'missing required field')):
        path.write_text(text)
        invoke(['server', '--config', path], contains=(explanation, 'server.json'))
    path.write_text('{}')
    invoke(['server', '--config', path], contains=('missing required field version',))
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
    server(missing, ('missing required field ports.gateway',))
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
    server(dict(config, version=3), ('executables.board is required',))
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
    invoke(['server'], contains=('--config is required',), env=dict(ENV, TRANSIT_CONSOLE_CONFIG=str(path)))
    assert not installation.exists()
print(f'CLI diagnostics passed: {CASES} real command cases; no configuration or credential disclosure, stdout contamination or provisioning.')
