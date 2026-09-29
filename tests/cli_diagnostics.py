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


def invoke(args, expected=2, contains=(), env=None, data=b''):
    global CASES
    result = subprocess.run([CLI, *map(str, args)], input=data, capture_output=True,
                            timeout=10, env=ENV if env is None else env)
    assert result.returncode == expected, (args, result.returncode, result.stdout, result.stderr)
    if expected:
        assert result.stdout == b'', (args, result.stdout)
        assert result.stderr.startswith(b'error: '), (args, result.stderr)
        for label in (b'\n  at: ', b'\n  cause: ', b'\n  next: ', b'\n  help: '):
            assert label in result.stderr, (args, label, result.stderr)
        assert b'private-must-not-appear' not in result.stderr, result.stderr
        assert b'\x1b' not in result.stderr and b'\r' not in result.stderr, result.stderr
        assert len(result.stderr) < 4096, (args, len(result.stderr))
    else:
        assert result.stderr == b'', result.stderr
    output = result.stderr if expected else result.stdout
    for fragment in contains:
        assert fragment.encode() in output, (args, fragment, output)
    CASES += 1
    return result


for command in ('server', 'serve'):
    invoke([command], contains=('missing required configuration', f'at: transit {command} --config', 'transit '+command+' --help'))
    invoke([command, '--config'], contains=('requires a value', 'argv[2] --config'))
    invoke([command, '--config', '--initialize'], contains=('requires a value', 'argv[2] --config'))
    invoke([command, '--config', ''], contains=('requires a value', 'argv[2] --config'))
    invoke([command, '--config', 'one', '--config', 'two'], contains=('more than once', 'argv[4] --config'))
    for flag in ('--initialize', '--no-ui', '--help'):
        invoke([command, flag, flag], contains=('more than once', f'argv[3] {flag}'))
    invoke([command, '--format', 'json'], contains=('not supported', 'argv[2] --format'))
    invoke([command, '--unknown=private-must-not-appear'], contains=('unexpected argument', 'argv[2]'))
    invoke([command, '--help'], 0, ('--config is required', '--initialize', '--no-ui'))
for args in ([], ['--help'], ['--version'], ['app'], ['app', '--help'], ['console', '--help'], ['query', '--help'], ['query-v2', '--help']):
    invoke(args, 0)
invoke(['private-must-not-appear'], contains=('unknown command', 'argv[1]', 'transit --help'))
invoke(['--help', 'extra'], contains=('argv[1]',))
invoke(['console'], contains=('TRANSIT_CONSOLE_CONFIG', '--config'))
invoke(['console', '--config', 'missing', '--format', 'csv'], contains=('unsupported output format', 'argv[5] --format', 'table', 'json'))
invoke(['console', '--config', 'missing', '--no-ui'], contains=('not supported', 'argv[4] --no-ui'))
for command in ('query', 'query-v2'):
    invoke([command], contains=('one configuration file', 'CONFIG'))
    invoke([command, 'one', 'two'], contains=('argv[3]',))
    invoke([command, '--config'], contains=('argv[2]',))
invoke(['app', 'private-must-not-appear'], contains=('unknown application subcommand', 'argv[2]'))
for mode in ('install', 'replace', 'retry', 'status', 'connect'):
    invoke(['app', mode], contains=(f'at: transit app {mode} --config', 'missing required'))
    invoke(['app', mode, '--config'], contains=('argv[3] --config', 'requires a value'))
    invoke(['app', mode, '--config', 'one', '--config', 'two'], contains=('argv[5] --config', 'more than once'))
invoke(['app', 'status', '--config', 'missing'], contains=('--application', 'missing required'))
invoke(['app', 'install', '--config', 'missing'], contains=('--file', 'missing required'))
invoke(['app', 'install', '--config', 'missing', '--file', 'missing'], contains=('--operation', 'missing required'))
invoke(['app', 'status', '--file', 'private-must-not-appear'], contains=('not supported', 'argv[3] --file'))
invoke(['app', 'status', '--after', '4294967296'], contains=('invalid receipt page index', 'argv[4] --after'))

with tempfile.TemporaryDirectory(prefix='transit-cli-diagnostics-') as directory:
    root = Path(directory)
    path = root / 'server.json'
    installation = root / 'installation'
    def server(config, contains, expected=2):
        path.write_text(json.dumps(config))
        return invoke(['server', '--config', path, '--no-ui'], expected, contains)

    for command in ('server', 'console'):
        invoke([command, '--config', root / 'missing.json'], contains=('cannot locate', 'missing.json', 'FileNotFound'))
    invoke(['app', 'status', '--config', root / 'missing.json', '--application', 'test'], contains=('cannot locate', 'FileNotFound'))
    for text, cause in (('{\n  "version": !\n}', 'SyntaxError'), ('{"version":1,"version":1}', 'DuplicateField'), ('{"private-must-not-appear":0}', 'UnknownField'), ('{}', 'MissingField')):
        path.write_text(text)
        invoke(['server', '--config', path], contains=(cause, 'parser location', 'server.json'))
    path.write_text('{}')
    invoke(['server', '--config', path], contains=('field version', 'MissingField'))
    path.write_text('{\n  "version": !\n}')
    invoke(['server', '--config', path], contains=('server.json":2:14 (parser location)',))
    path.write_bytes(b' ' * 65537)
    invoke(['server', '--config', path], contains=('size limit', 'StreamTooLong'))
    invoke(['server', '--config', str(root / 'evil\x1b[31m\n.json')], contains=('\\x1b', '\\x0a'))
    invoke(['server', '--config', 'x' * 4096], contains=('...', 'cannot locate'))

    config = {'version': 1, 'installation': str(installation), 'realm': 73,
              'ports': dict(zip(('cold', 'cold_console', 'store', 'node', 'gateway'), range(29001, 29006))),
              'executables': dict.fromkeys(('minio', 'ursula', 'node', 'query_host'), sys.executable)}
    missing = copy.deepcopy(config)
    del missing['ports']['gateway']
    server(missing, ('field ports.gateway', 'MissingField'))
    for key, value, field in (('version', 4, 'version'), ('realm', 0, 'realm'), ('admission_ceiling', 127, 'admission_ceiling'), ('control_reserve', 65537, 'control_reserve'), ('gateway_allowed_hosts', ['private-must-not-appear'], 'gateway_allowed_hosts')):
        invalid = dict(config, **{key: value})
        server(invalid, ('field '+field,))
    invalid = copy.deepcopy(config)
    invalid['ports']['gateway'] = invalid['ports']['node']
    server(invalid, ('field ports.gateway / ports.node', 'same port'))
    invalid['ports']['gateway'] = 80
    server(invalid, ('field ports.gateway', 'below 1024'))
    invalid = copy.deepcopy(config)
    invalid['executables']['query_host'] = 'private-must-not-appear'
    server(invalid, ('field executables.query_host', 'FileNotFound'))
    server(dict(config, version=3), ('field executables.board', 'Board executable is missing'))
    path.write_text(json.dumps(config))
    invoke(['server', '--config', path], contains=('field version', '--no-ui'))
    with socket.socket() as listener:
        listener.bind(('127.0.0.1', 0))
        listener.listen()
        port = listener.getsockname()[1]
        invalid = copy.deepcopy(config)
        invalid['ports']['cold'] = port
        server(invalid, ('cannot bind', 'field ports.cold', f'127.0.0.1:{port}'), 1)
    assert not installation.exists(), 'invalid invocation/configuration started provisioning'

    console = {'version': 1, 'profile': 'unified_v2', 'url': 'http://127.0.0.1:19105', 'transport': 'loopback',
               'seed_file': 'missing.seed', 'connection': dict(zip(('realm', 'principal', 'source', 'resource', 'requester', 'requests'), range(1, 7))),
               'workspace': {'name': 'items', 'source': {'resource': 4, 'source': {'table': {'id': 1, 'names': ['key', 'value'], 'value_type': 'int64'}}},
                             'limits': {'pages': '1', 'segments': '1', 'result_bytes': '65536'}}}
    path = root / 'console.json'
    for patch, field in (({'version': 2}, 'version'), ({'request_timeout_ms': 0}, 'request_timeout_ms'), ({'url': 'http://user:private-must-not-appear@127.0.0.1:19105'}, 'url / transport / ca_file')):
        path.write_text(json.dumps(dict(console, **patch)))
        invoke(['console', '--config', path, '--format', 'json'], contains=('field '+field, 'invalid console configuration'))
    missing = copy.deepcopy(console)
    del missing['workspace']['source']['source']['table']['id']
    path.write_text(json.dumps(missing))
    invoke(['console', '--config', path], contains=('field workspace.source.source.table.id', 'MissingField'))
    path.write_text(json.dumps(dict(console, url='https://localhost:19105', transport='tls_ca', ca_file='missing.pem')))
    invoke(['console', '--config', path], contains=('field ca_file', 'FileNotFound', 'CA certificates'))
    path.write_text(json.dumps(console))
    invoke(['console', '--config', path], contains=('field seed_file', 'FileNotFound', 'signing credential'))
    invoke(['console'], contains=('field seed_file',), env=dict(ENV, TRANSIT_CONSOLE_CONFIG=str(path)))
    invoke(['console', '--config', root/'override.json'], contains=('override.json',), env=dict(ENV, TRANSIT_CONSOLE_CONFIG=str(path)))
    invoke(['server'], contains=('missing required configuration',), env=dict(ENV, TRANSIT_CONSOLE_CONFIG=str(path)))
    assert not installation.exists()
print(f'CLI diagnostics passed: {CASES} real command cases; no configuration or credential disclosure, stdout contamination or provisioning.')
