#!/usr/bin/env python3
"""Real CLI failures: actionable coordinates, privacy, streams and no startup effects."""
import copy
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
from console_settings import parse_show, read_show

CLI = str(Path(sys.argv[1]).resolve())
ENV = {key: value for key, value in os.environ.items() if not key.startswith('TRANSIT_')}
CASES = 0
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


for command in ('server', 'serve'):
    invoke([command], contains=('cannot find minio beside transit or on PATH',),
           env=ENV | {'PATH': str(NO_TOOLS)}, binary=str(ISOLATED_CLI))
    for value in ([], ['--initialize'], ['']):
        invoke([command, '--config', *value], stderr='error: --config requires a file path\n')
    invoke([command, '--config', 'one', '--config', 'two'], stderr='error: --config can only be specified once\n')
    for flag in ('--initialize', '--no-ui', '--help'):
        invoke([command, flag, flag], stderr=f'error: {flag} can only be specified once\n')
    invoke([command, '--format', 'json'], contains=('--format is not supported', f'transit {command} --help'))
    invoke([command, '--unknown=private-must-not-appear'], contains=('unexpected input at argument 2',))
    invoke([command, '--help'], 0, ('Server configuration file (overrides discovery)', '--initialize', '--no-ui', 'Alias: serve'))
    invoke([command, '--config', 'private-must-not-appear', '--help'], 0)
for args in ([], ['--help'], ['--version'], ['app'], ['app', '--help'], ['console', '--help'], ['query', '--help']):
    invoke(args, 0)
root_help = invoke(['--help'], 0, ('Usage: transit COMMAND [OPTIONS]', 'Commands:', 'Options:')).stdout
assert b'--initialize' not in root_help and b'--config' not in root_help
invoke(['private-must-not-appear'], contains=('unknown command', 'argument 1', 'transit --help'))
invoke(['--help', 'extra'], contains=('argument 1',))
invoke(['console', '--no-rc'], contains=('cannot read the local installation', 'installation.json'))
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
for command in ('query',):
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

# Mutation invocation and local capabilities need no credential discovery or I/O.
invoke(['mutate'], 0, ('Only submit sends a command',))
invoke(['mutate', '--help'], 0, ('transit mutate COMMAND',))
capabilities = json.loads(invoke(['mutate', 'capabilities'], 0).stdout)['capabilities']
assert capabilities['max_rows'] == 3 and capabilities['max_saved_bytes'] == 8192
invoke(['mutate', 'private-must-not-appear'], contains=('unknown mutation subcommand', 'argument 2'))
for mode in ('describe', 'compile', 'next', 'prepare', 'submit', 'observe', 'rejection', 'status'):
    invoke(['mutate', mode], contains=(f'Usage: transit mutate {mode}', '--config is required'))
    invoke(['mutate', mode, '--help'], 0, (f'Usage: transit mutate {mode}', 'Only submit sends a command'))
    invoke(['mutate', mode, '--config', 'private-must-not-appear', '--help'], 0)
    invoke(['mutate', mode, '--help', '--config'], stderr='error: --config requires a file path\n')
    invoke(['mutate', mode, '--help', '--unknown=private-must-not-appear'], contains=('argument 4',))
    invoke(['mutate', mode, '--config', 'one', '--config', 'two'], stderr='error: --config can only be specified once\n')
invoke(['mutate', 'submit', '--output', 'private-must-not-appear'], contains=('--output is not supported',))
invoke(['mutate', 'capabilities', '--config', 'private-must-not-appear'], contains=('--config is not supported',))
invoke(['mutate', 'compile', '--namespace', '18446744073709551616'], contains=('positive uint64',))
invoke(['mutate', 'compile', '--namespace', '0'], contains=('positive uint64',))
invoke(['mutate', 'observe', '--input', '9007199254740992'], contains=('positive native position',))
invoke(['mutate', 'prepare', '--control', 'private-must-not-appear'], contains=('must be apply or cancel',))

# Catalog options validate before configuration; compilation needs no endpoint/key.
invoke(['catalog'], 0, ('Only submit sends a command',))
invoke(['catalog', '--help'], 0, ('transit catalog COMMAND',))
capabilities = json.loads(invoke(['catalog', 'capabilities'], 0).stdout)['capabilities']
assert capabilities['max_columns'] == 128 and capabilities['max_rows'] == 1024 and capabilities['max_prepared_bytes'] == 8192
invoke(['catalog', 'private-must-not-appear'], contains=('unknown catalog subcommand', 'argument 2'))
for mode in ('describe', 'lookup', 'definition', 'list', 'compile', 'prepare', 'next', 'prepare-initialize', 'prepare-policy', 'prepare-dependency', 'prepare-resume', 'cancel', 'cleanup', 'cancel-upload', 'collect-upload', 'submit', 'observe', 'disposition', 'progress', 'status'):
    invoke(['catalog', mode], contains=(f'Usage: transit catalog {mode}', '--config is required'))
    invoke(['catalog', mode, '--help'], 0, (f'Usage: transit catalog {mode}', 'Only submit sends a command'))
    invoke(['catalog', mode, '--config', 'private-must-not-appear', '--help'], 0)
    invoke(['catalog', mode, '--help', '--config'], stderr='error: --config requires a file path\n')
    invoke(['catalog', mode, '--help', '--unknown=private-must-not-appear'], contains=('argument 4',))
    invoke(['catalog', mode, '--config', 'one', '--config', 'two'], stderr='error: --config can only be specified once\n')
    invoke(['catalog', mode, '--help', '--help'], stderr='error: --help can only be specified once\n')
for mode, flag in [('capabilities', '--config'), ('submit', '--output'), ('describe', '--file'), ('status', '--operation'), ('lookup', '--file'), ('definition', '--name'), ('list', '--revision')]:
    invoke(['catalog', mode, flag, 'private-must-not-appear'], contains=(flag + ' is not supported',))
for flag in ('--operation', '--object', '--namespace'):
    for value in ('0', '00', '+1', '-1', '01', '18446744073709551616'):
        invoke(['catalog', 'compile', flag, value], contains=('canonical positive uint64',))
invoke(['catalog', 'compile', '--table', '1'], contains=('unexpected input at argument 3',))
for mode in ('observe', 'disposition', 'progress'):
    for value in ('0', '01', '9007199254740992'):
        invoke(['catalog', mode, '--input', value], contains=('canonical positive native position',))
invoke(['catalog', 'lookup', '--config', 'missing'], contains=('--name is required',))
invoke(['catalog', 'definition', '--config', 'missing'], contains=('--object is required',))
invoke(['catalog', 'definition', '--config', 'missing', '--object', '1'], contains=('--revision is required',))
for value in ('x'*256, 'é'*128):
    invoke(['catalog', 'lookup', '--name', value], contains=('1 through 255 UTF-8',))
for value in ('1name', 'with space', 'name.with.dot', 'caf\u00e9'):
    invoke(['catalog', 'lookup', '--name', value, '--help'], 0)
for flag in ('--object', '--revision'):
    for value in ('0', '00', '+1', '-1', '01', '18446744073709551616'):
        invoke(['catalog', 'definition', flag, value], contains=('canonical positive uint64',))

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
    invoke(['mutate', 'describe', '--config', root / 'missing.json'], contains=('configuration file', 'was not found'))
    catalog_config = root / 'catalog.json'
    catalog_values = dict(version=1, connection=dict(scope=dict(realm=46, resource=2, catalog='18446744073709551615'), owner=1, principal=1234))
    sql = root / 'create.sql'
    sql.write_text('CREATE TABLE items (id INT64 NOT NULL, value UTF8 NULL)')
    compiled_path = root / 'compiled.json'
    compile_args = ['catalog', 'compile', '--config', catalog_config, '--operation', '18446744073709551615', '--object', '18446744073709551615', '--namespace', '18446744073709551615', '--file', sql, '--output', compiled_path]
    catalog_config.write_text(json.dumps(catalog_values))
    compiled = json.loads(invoke(compile_args, 0).stdout)
    assert json.loads(compiled_path.read_bytes()) == compiled
    assert compiled_path.stat().st_mode & 0o777 == 0o600
    assert compiled['compiled']['intent']['operation'] == '18446744073709551615'
    original = compiled_path.read_bytes()
    invoke(compile_args, 1, ('PathAlreadyExists',))
    assert compiled_path.read_bytes() == original
    invoke(['catalog', 'describe', '--config', catalog_config], contains=('url', 'is required'))
    for field, value in [('version', 2), ('url', 'http://private-must-not-appear@127.0.0.1:1'), ('request_timeout_ms', 60001)]:
        catalog_config.write_text(json.dumps(dict(catalog_values, **{field:value})))
        invoke(compile_args, contains=(field,))
    invalid_values = copy.deepcopy(catalog_values)
    invalid_values['connection']['scope']['catalog'] = 18446744073709551615
    catalog_config.write_text(json.dumps(invalid_values))
    invoke(compile_args, contains=('configuration', 'invalid or missing field'))
    invalid_values['connection']['scope']['catalog'] = '01'
    catalog_config.write_text(json.dumps(invalid_values))
    invoke(compile_args, contains=('connection', 'canonical positive catalog ID string'))
    invalid_values['connection']['scope']['catalog'] = '1'
    invalid_values['connection']['scope']['realm'] = '46'
    catalog_config.write_text(json.dumps(invalid_values))
    invoke(compile_args, contains=('configuration', 'invalid or missing field'))
    catalog_config.write_text(json.dumps(dict(catalog_values, url='http://127.0.0.1:1')))
    invoke(['catalog', 'describe', '--config', catalog_config], contains=('seed_file', 'is required'))
    catalog_config.write_text(json.dumps(dict(catalog_values, url='http://127.0.0.1:1', seed_file='missing.seed')))
    bad_compiled = root / 'bad-compiled.json'
    invalid_compiled = copy.deepcopy(compiled)
    invalid_compiled['compiled']['intent']['object'] = '12'
    bad_compiled.write_text(json.dumps(invalid_compiled))
    for mode in ('next', 'status'):
        args = ['catalog', mode, '--config', catalog_config, '--file', bad_compiled]
        if mode == 'next': args += ['--output', root / 'must-not-exist.json']
        invoke(args, 1, ('CatalogArtifactMismatch',))
    invalid_compiled = copy.deepcopy(compiled)
    canonical = bytearray.fromhex(invalid_compiled['compiled']['saved']['bytes'])
    canonical[5] ^= 1  # Foreign current-definition bytes must never be adopted.
    invalid_compiled['compiled']['saved']['bytes'] = canonical.hex()
    bad_compiled.write_text(json.dumps(invalid_compiled))
    invoke(['catalog', 'status', '--config', catalog_config, '--file', bad_compiled], 1, ('IncompatibleDefinition',))
    invalid_compiled = copy.deepcopy(compiled)
    del invalid_compiled['compiled']['saved']['definition']
    bad_compiled.write_text(json.dumps(invalid_compiled))
    invoke(['catalog', 'status', '--config', catalog_config, '--file', bad_compiled], contains=('artifact', 'invalid or missing field'))
    bad_prepared = root / 'bad-catalog-prepared.json'
    bad_prepared.write_text('{"prepared":null}')
    invoke(['catalog', 'submit', '--config', catalog_config, '--file', bad_prepared], contains=('artifact', 'invalid or missing field'))
    bad_prepared.write_text('{"prepared":"{}"}')
    invoke(['catalog', 'submit', '--config', catalog_config, '--file', bad_prepared], 1, ('InvalidCatalogPrepared',))
    # Entire saved pages, including mandatory definition and continuation
    # consistency, validate before reading the missing signing credential.
    # A complete current-format neutral page, with independently selected IDs.
    page_scope = dict(realm=46, resource=2, catalog='42')
    page = dict(resource_revision=20, entries=[dict(
        metadata=dict(scope=page_scope, object='81', revision='1', name='東京 people',
            schema_fingerprint='11'*32, principal=1234, operation='71', admitted_input=17,
            commitment=dict(format=0x54434d01, length=200, digest=[2]*32)),
        head=dict(revision='1', rows='0', pending='0'))] + [None]*7,
        next=dict(definition=compiled['compiled']['saved']['definition'], scope=page_scope,
            resource_revision=20, after_object='81'))
    page_path = root / 'catalog-page.json'
    page_args = ['catalog', 'list', '--config', catalog_config, '--file', page_path]
    for foreign in (None, '0' * 64):
        invalid_page = copy.deepcopy(page)
        if foreign is None: del invalid_page['next']['definition']
        else: invalid_page['next']['definition'] = foreign
        page_path.write_text(json.dumps(dict(page=invalid_page)))
        invoke(page_args, contains=('artifact', 'invalid or missing field'))
    invalid_page = copy.deepcopy(page)
    invalid_page['next'] = None
    page_path.write_text(json.dumps(dict(page=invalid_page)))
    invoke(page_args, contains=('page.next', 'saved page has no continuation'))
    for malformed in ('hole', 'scope', 'revision', 'object'):
        invalid_page = copy.deepcopy(page)
        if malformed == 'hole': invalid_page['entries'][1], invalid_page['entries'][0] = invalid_page['entries'][0], None
        elif malformed == 'scope': invalid_page['next']['scope'] = dict(invalid_page['next']['scope'], catalog='1')
        elif malformed == 'revision': invalid_page['next']['resource_revision'] += 1
        else: invalid_page['next']['after_object'] = '80'
        page_path.write_text(json.dumps(dict(page=invalid_page)))
        invoke(page_args, 1, ('InvalidCatalogPage',))
    invalid_page = copy.deepcopy(page)
    invalid_page['entries'][0]['metadata']['object'] = '01'
    page_path.write_text(json.dumps(dict(page=invalid_page)))
    invoke(page_args, 1, ('InvalidCatalogInteger',))
    # Native root zero is a valid author, while resource/input identities remain
    # positive. Passing local metadata validation does not supply a credential.
    for principal in (0, 1234, 2**53 - 1):
        authored_page = copy.deepcopy(page)
        authored_page['entries'][0]['metadata']['principal'] = principal
        page_path.write_text(json.dumps(dict(page=authored_page)))
        invoke(page_args, contains=('cannot load the catalog signing credential',))
    invalid_page = copy.deepcopy(page)
    invalid_page['entries'][0]['metadata']['principal'] = 2**53
    page_path.write_text(json.dumps(dict(page=invalid_page)))
    invoke(page_args, 1, ('InvalidCatalogPage',))
    yaml_config = root / 'catalog.yaml'
    yaml_config.write_text("version: 1\nconnection:\n  scope:\n    realm: 46\n    resource: 2\n    catalog: '18446744073709551615'\n  owner: 1\n  principal: 1234\n")
    yaml_args = list(compile_args)
    yaml_args[3] = yaml_config
    yaml_args[-1] = root / 'yaml-compiled.json'
    assert json.loads(invoke(yaml_args, 0).stdout) == compiled
    assert not (root / 'must-not-exist.json').exists()
    mutation_config = root / 'mutation.json'
    mutation_values = dict(version=1,url='http://127.0.0.1:1',seed_file='missing.seed',connection=dict(realm=46,principal=1234,writer=1,resource=2,table=1))
    mutation_config.write_text(json.dumps(dict(mutation_values,version=2)))
    invoke(['mutate', 'describe', '--config', mutation_config], contains=('version', 'must be 1'))
    mutation_config.write_text(json.dumps(dict(mutation_values,url='http://private-must-not-appear@127.0.0.1:1')))
    invoke(['mutate', 'describe', '--config', mutation_config], contains=('url', 'without embedded credentials'))
    mutation_config.write_text(json.dumps(mutation_values))
    invalid_prepared = root / 'invalid-prepared.json'
    invalid_prepared.write_text('{"prepared":null}')
    invoke(['mutate', 'submit', '--config', mutation_config, '--file', invalid_prepared], 1, ('NoPreparedMutation',))
    invalid_prepared.write_text('{"prepared":"{}"}')
    invoke(['mutate', 'submit', '--config', mutation_config, '--file', invalid_prepared], 1, ('InvalidMutationPrepared',))
    # Malformed artifacts fail before the missing key could be loaded.
    for text, explanation in (('{\n  "version": !\n}', 'invalid JSON'), ('{"version":1,"version":1}', 'duplicate field'), ('{"private-must-not-appear":0}', 'unknown field')):
        path.write_text(text)
        invoke(['server', '--config', path], contains=(explanation, 'server.json'))
    path.write_text('{}')
    invoke(['server', '--config', path], contains=('cannot find minio beside transit or on PATH',),
           env=ENV | {'PATH': str(NO_TOOLS)}, binary=str(ISOLATED_CLI))
    path.write_text('{\n  "version": !\n}')
    invoke(['server', '--config', path], contains=('server.json":2:14',))
    path.write_bytes(b' ' * 65537)
    invoke(['server', '--config', path], contains=('size limit',))
    invoke(['server', '--config', str(root / 'evil\x1b[31m\n.json')], contains=('\\x1b', '\\x0a'))
    invoke(['server', '--config', 'x' * 4096], contains=('...', 'cannot read configuration file'))

    config = {'version': 1, 'installation': str(installation), 'realm': 73,
              'ports': dict(zip(('cold', 'cold_console', 'store', 'node', 'gateway'), range(29001, 29006))),
              'executables': dict.fromkeys(('minio', 'ursula', 'node', 'query_host', 'board'), sys.executable)}
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
    server(dict(config, version=2), ('version must be 1',))
    server(dict(config, version=3), ('version must be 1',))
    with socket.socket() as listener:
        listener.bind(('127.0.0.1', 0))
        listener.listen()
        port = listener.getsockname()[1]
        invalid = copy.deepcopy(config)
        invalid['ports']['cold'] = port
        server(invalid, ('cannot bind', 'ports.cold', 'address already in use', f'127.0.0.1:{port}'), 1)
    assert not installation.exists(), 'invalid invocation/configuration started provisioning'

    console = {'version': 1, 'profile': 'unified_v1', 'url': 'http://127.0.0.1:19105', 'transport': 'loopback',
               'seed_file': 'missing.seed', 'connection': dict(zip(('realm', 'principal', 'source', 'resource', 'requester', 'requests'), range(1, 7))),
               'workspace': {'name': 'items', 'source': {'resource': 4, 'source': {'table': {'scope': {'realm': 1, 'resource': 4, 'catalog': '1'}, 'owner': 3, 'object': '1', 'metadata': {'id': '1', 'spec': {'format': 0x54434d01, 'length': 200, 'digest': [1]*32}}, 'row_type': {'structure': [{'name': 'key', 'type': {'int64': {}}}, {'name': 'value', 'type': {'int64': {}}, 'nullable': True}]}}}},
                             'limits': {'pages': '1', 'segments': '1', 'result_bytes': '65536'}}}
    path = root / 'console.json'
    catalog_console = dict(version=1, profile='catalog_v1', url=console['url'], transport='loopback',
                           seed_file='missing.seed', catalog=dict(scope=dict(realm=1, resource=4, catalog=1), owner=3, principal=2))
    for patch, field in (({'connection': console['connection']}, 'catalog'),
                         ({'workspace': console['workspace']}, 'catalog'),
                         ({'catalog': None}, 'catalog'),
                         ({'execution': 'durable'}, 'execution'),
                         ({'writes': {'recovery_file': ''}}, 'writes.recovery_file')):
        path.write_text(json.dumps(dict(catalog_console, **patch)))
        invoke(['console', '--config', path], contains=(field, 'invalid console configuration'))
    path.write_text(json.dumps(catalog_console))
    invoke(['console', '--config', path], contains=('seed_file', 'signing credential'))
    for patch, field in (({'version': 2}, 'version'), ({'request_timeout_ms': 0}, 'request_timeout_ms'), ({'url': 'http://user:private-must-not-appear@127.0.0.1:19105'}, 'url / transport / ca_file')):
        path.write_text(json.dumps(dict(console, **patch)))
        invoke(['console', '--config', path, '--format', 'json'], contains=(field,))
    missing = copy.deepcopy(console)
    del missing['workspace']['source']['source']['table']['object']
    path.write_text(json.dumps(missing))
    invoke(['console', '--config', path], contains=('missing required field workspace.source.source.table.object',))
    path.write_text(json.dumps(dict(console, url='https://localhost:19105', transport='tls_ca', ca_file='missing.pem')))
    invoke(['console', '--config', path], contains=('ca_file', 'file not found', 'CA certificates'))
    path.write_text(json.dumps(console))
    invoke(['console', '--config', path], contains=('seed_file', 'file not found', 'signing credential'))
    invoke(['console'], contains=('seed_file',), env=dict(ENV, TRANSIT_CONSOLE_CONFIG=str(path)))
    invoke(['console', '--config', root/'override.json'], contains=('override.json',), env=dict(ENV, TRANSIT_CONSOLE_CONFIG=str(path)))
    invoke(['server'], contains=('cannot find minio beside transit or on PATH',),
           env=dict(ENV, PATH=str(NO_TOOLS), TRANSIT_CONSOLE_CONFIG=str(path)), binary=str(ISOLATED_CLI))
    # Compiler failures need no running authority, even in JSON result mode.
    # A listening trap proves invalid SQL never opens a snapshot or sends work.
    seed = root/'sql.seed'
    seed.write_text('2a' * 32)
    with socket.socket() as trap:
        trap.bind(('127.0.0.1', 0)); trap.listen(); trap.settimeout(.1)
        sql_config = dict(console, seed_file=seed.name, url=f'http://127.0.0.1:{trap.getsockname()[1]}')
        path.write_text(json.dumps(sql_config))
        for statement, fragments in (
            ('SELECT;', ('SQL parse error', 'line 1, column 7', '  SELECT;\n        ^--- error here')),
            ('SELECT *\nFROM', ('SQL parse error', 'line 2, column 5', 'expected an identifier')),
            ('INSERT INTO items VALUES (1, 100);', ('no Table catalog is configured', '.help INSERT')),
            ('INSERT INTO items (id, value) VALUES (1, 100);', ('no Table catalog is configured', '.help INSERT')),
            ('SELECT * FROM items WHERE value = \'private-must-not-appear', ('SQL parse error', '^--- error here')),
            ('SELECT * /* private-must-not-appear', ('SQL parse error', '^--- error here')),
            ('CREATE KV items (UTF8);', ('[interface]', 'SQL publication of KV and Document definitions is unavailable', '.help SQL')),
            ('CREATE TABLE items (id INT64 NOT NULL, value INT64 NULL);', ('no Table catalog is configured', '.help CREATE TABLE')),
            ('CREATE TABLE items (id INT64, value INT64);', ('no Table catalog is configured', '.help CREATE TABLE')),
            ('CREATE TABLE items (id BOOLEAN);', ('no Table catalog is configured', '.help CREATE TABLE')),
            ('INSERT INTO items (id,value) VALUES (1,1),(2,2),(3,3),(4,4);', ('no Table catalog is configured', '.help INSERT')),
            ('CREATE CONNECTION unfinished', ('[grammar_only]', 'syntax has not been validated')),
            ('SELEC * FROM items;', ('[unsupported]', 'supported syntax')),
            ('SELECT absent FROM items;', ('[binding]', 'Subject: \"absent\"', 'scope: \"items\"', 'column 8')),
            ('SELECT wrong.value FROM items AS i;', ('UnknownQualifier', 'Subject: \"wrong\"', 'scope: \"i\"')),
            ("SELECT * FROM items WHERE key=1 AND value='wrong';", ('TypeMismatch', 'Subject: \"value\"', 'Expected int64; supplied utf8')),
            ('SELECT AVG(value) FROM items;', ('Unsupported aggregate', 'COUNT(*)', 'SUM')),
            ('SHOW SOURCES;', ('[grammar_only]', 'SHOW SOURCES')),
            ('SHOW SINKS;', ('[grammar_only]', 'SHOW SINKS')),
            ('SHOW CONNECTIONS;', ('[grammar_only]', 'SHOW CONNECTIONS')),
            ('SELECT value AS;', ('[syntax]', 'line 1, column 16', 'expected an identifier')),
            ('SELECT value AS copy, value AS copy FROM items;', ('[binding]', 'DuplicateProjection', 'distinct result names', 'AS')),
            ('SELECT key AS copy, value AS copy FROM items;', ('[binding]', 'DuplicateColumn', 'distinct result names', 'AS')),
            ('SELECT * FROM items WHERE value = NULL;', ('[binding]', 'IS NULL', 'IS MISSING')),
        ):
            invoke(['console', '--no-rc', '--config', path, '--format', 'json', '-c', statement], 1, fragments)
        invoke(['console', '--no-rc', '--config', path], 1, ('no Table catalog is configured', '.help INSERT'), data=b'.schema writer\n')
        script = root/'bad.sql'
        script.write_text('SELECT *\nFROM;')
        invoke(['console', '--no-rc', '--config', path, '-f', script], 1, ('line 2, column 5', '^--- error here'))
        script.write_text('-- 東京\r\n\r\n.show\r\n  SELECT absent FROM items;')
        invoke(['console', '--no-rc', '--config', path, '-f', script], 1,
               ('bad.sql', 'statement 2', 'line 4, column 10', 'Previously completed commands: 1'),
               stdout_contains=('format',))
        invoke(['console', '--no-rc', '--config', path], 1,
               ('<stdin>', 'statement 2', 'line 2, column 8', 'Previously completed commands: 1'),
               data=b'.show\nSELECT absent FROM items;', stdout_contains=('format',))
        byte_path = Path(os.fsdecode(os.fsencode(root) + b'/script-\xff.sql'))
        byte_path.write_bytes(b'.show\nSELECT absent FROM items;')
        invoke(['console', '--no-rc', '--config', path, '-f', byte_path], 1,
               ('script-\\xff.sql', '[escaped byte path]', 'statement 2', 'line 2, column 8'),
               stdout_contains=('format',))
        invoke(['console', '--no-rc', '--config', path], 1, ('line 1, column 7',), data=b'SELECT;')
        for data in (b"SELECT * FROM items WHERE value = 'private-must-not-appear", b'SELECT * /* private-must-not-appear'):
            invoke(['console', '--no-rc', '--config', path], 1, ('SQL parse error', '^--- error here'), data=data)
        invoke(['console', '--no-rc', '--config', path], 1, ('4096-byte statement limit',), data=b'SELECT '+b'x'*4096)
        try:
            connection, _ = trap.accept()
        except TimeoutError:
            pass
        else:
            connection.close()
            raise AssertionError('invalid SQL contacted authority')
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
    yaml_config = 'version: 1\nrealm: 0\nexecutables:\n'+''.join(f'  {key}: {sys.executable}\n' for key in ('minio', 'ursula', 'node', 'query_host', 'board'))
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
        ('CREATE TABLE people (id INT64, name BINARY);', '.help CREATE TABLE'),
        ('SELECT;', '.help SQL'),
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
    from console_terminal import ANSI, Terminal
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
    # Inspect the committed scrollback echo, not the editor's transient redraws.
    # SQL errors retain the same text and caret with and without presentation.
    def committed_display(terminal, statement):
        expected = ('transit> '+statement.replace('\n', '\r\n   ...> ')+'\r\n').encode()
        for redraw in terminal.screen.split(b'\r\x1b[2K'):
            if ANSI.sub(b'', redraw).startswith(expected):
                lines = redraw.split(b'\r\n')
                count = statement.count('\n')+1
                return b'\r\n'.join(lines[:count])+b'\r\n', b'\r\n'.join(lines[count:])
        raise AssertionError(('missing submitted echo', expected, terminal.screen))

    sgr = re.compile(rb'\x1b\[[0-9;]*m')
    reset = b'\x1b[0m'
    def assert_sql_colors(rendered, text, tokens):
        # Assert every visible byte, including plain names and punctuation.
        plain, actual, active, offset = bytearray(), [], None, 0
        for escape in ANSI.finditer(rendered):
            part = rendered[offset:escape.start()]
            plain.extend(part)
            actual.extend([active] * len(part))
            code = escape.group()
            if code.endswith(b'm'):
                active = None if code == reset else code
            offset = escape.end()
        plain.extend(rendered[offset:])
        actual.extend([active] * (len(rendered)-offset))
        assert bytes(plain) == text, (plain, text)
        expected, offset = [None] * len(text), 0
        for token, code in tokens:
            start = text.index(token, offset)
            offset = start + len(token)
            expected[start:offset] = [code] * len(token)
        assert actual == expected, (rendered, tokens)

    plain_diagnostics = {}
    for format in ('table', 'json'):
        for color_env, colored in (
            ({'TERM': 'xterm-256color', 'NO_COLOR': '', 'CLICOLOR_FORCE': ''}, True),
            ({'TERM': 'xterm-256color', 'NO_COLOR': '1', 'CLICOLOR_FORCE': '1'}, False),
            ({'TERM': 'dumb', 'NO_COLOR': '', 'CLICOLOR_FORCE': '1'}, False),
        ):
            terminal = Terminal(CLI, connection, format=format, cwd=project, env=color_env)
            try:
                terminal.send('.timer on\r')
                terminal.expect('transit> .timer on\r\n')
                echo, _ = committed_display(terminal, '.timer on')
                assert (b'\x1b[36mtimer'+reset in echo) == colored, echo
                for statement, hint, category, cause in (
                    ('.unknown', '.help', None, 'UnknownConsoleCommand'),
                    ('CREATE TABLE people (id INT64, id BINARY);', '.help CREATE TABLE', 'binding', 'DuplicateColumn'),
                    ('CREATE TABLE people (id , name TEXT);', '.help CREATE TABLE', 'syntax', 'InvalidSqlSyntax'),
                    ("SELECT /* private-comment */\n'private-literal', 12;", '.help SQL', 'syntax', 'InvalidSqlSyntax'),
                ):
                    terminal.send('\x1b[200~'+statement+'\x1b[201~\r')
                    terminal.expect(hint)
                    if category is not None:
                        terminal.expect('ms)\r\n')
                    echo, diagnostic = committed_display(terminal, statement)
                    plain = ANSI.sub(b'', diagnostic)
                    # Timing values vary; all other diagnostic bytes must agree.
                    content = plain.split(b'Time: ')[0]
                    if statement in plain_diagnostics:
                        assert content == plain_diagnostics[statement], (content, plain_diagnostics[statement])
                    else:
                        plain_diagnostics[statement] = content
                    assert b'private-' not in diagnostic, diagnostic
                    if category is not None:
                        assert plain.count(b'Time: ') == 1 and plain.splitlines()[-1].startswith(b'Time: '), plain
                    if colored:
                        assert b'\x1b[36m'+statement.lstrip('.').split()[0].encode()+reset in echo, echo
                        assert b'\x1b[1;31merror:'+reset in diagnostic, diagnostic
                        assert b'\x1b[1;31m'+cause.encode()+reset in diagnostic, diagnostic
                        assert b'\x1b[36m.help'+reset in diagnostic, diagnostic
                        if category:
                            assert b'[\x1b[33m'+category.encode()+reset+b']' in diagnostic, diagnostic
                        if category == 'syntax':
                            assert b'\x1b[1;31m^--- error here'+reset in diagnostic, diagnostic
                            location = b'line 1, column 25' if statement.startswith('CREATE') else b'line 2, column 1'
                            assert b'\x1b[36m'+location+reset in diagnostic, diagnostic
                        if '\n' in statement:
                            for token in (b'\x1b[2m/* private-comment */'+reset, b"\x1b[32m'private-literal'"+reset, b'\x1b[35m12'+reset):
                                assert token in echo, echo
                        assert echo.endswith(reset+b'\r\n'), echo
                    else:
                        assert not sgr.search(terminal.screen), terminal.screen
                    assert not select.select([terminal.process.stdout], [], [], .05)[0], 'diagnostic leaked to stdout'
                cyan, green = b'\x1b[36m', b'\x1b[32m'
                for statement, hint, tokens in (
                    ('SELECT value FROM items WHERE value IS VALUE LIMIT;', '.help SQL',
                     ((b'SELECT', cyan), (b'FROM', cyan), (b'WHERE', cyan), (b'IS', cyan), (b'VALUE', cyan), (b'LIMIT', cyan))),
                    ('EXPLAIN SELECT value AS explain FROM update WHERE value IS VALUE LIMIT;', '.help SQL',
                     ((b'EXPLAIN', cyan), (b'SELECT', cyan), (b'AS', cyan), (b'FROM', cyan), (b'WHERE', cyan), (b'IS', cyan), (b'VALUE', cyan), (b'LIMIT', cyan))),
                    ('INSERT INTO update (id, value) VALUES (1, TRUE) trailing;', '.help INSERT',
                     ((b'INSERT', cyan), (b'INTO', cyan), (b'VALUES', cyan), (b'1', b'\x1b[35m'), (b'TRUE', green))),
                ):
                    # These fail locally, after the contextual tokens. No server
                    # or binding success is needed to color an editable draft.
                    terminal.resize(160)
                    terminal.send('\x1b[200~'+statement+'\x1b[201~')
                    terminal.expect('transit> '+statement)
                    draft = terminal.screen.split(b'\r\x1b[2K')[-1]
                    # The editor appends cursor movement after its text.
                    assert_sql_colors(draft, ('transit> '+statement+'\r').encode(), tokens if colored else ())
                    terminal.send('\r')
                    terminal.expect(hint)
                    terminal.expect('ms)\r\n')
                    echo, diagnostic = committed_display(terminal, statement)
                    assert_sql_colors(echo, ('transit> '+statement+'\r\n').encode(), tokens if colored else ())
                    content = ANSI.sub(b'', diagnostic).split(b'Time: ')[0]
                    if statement in plain_diagnostics:
                        assert content == plain_diagnostics[statement], (content, plain_diagnostics[statement])
                    else:
                        plain_diagnostics[statement] = content
                    if colored and b'IS VALUE' in statement.encode():
                        assert cyan+b'VALUE'+reset in diagnostic, diagnostic
                        assert cyan+b'value'+reset not in diagnostic, diagnostic
                    if not colored:
                        assert not sgr.search(terminal.screen), terminal.screen
                    assert not select.select([terminal.process.stdout], [], [], .05)[0], 'highlighting sent a query or leaked a diagnostic'
                    CASES += 1
                terminal.send('.show\r')
                assert read_show(terminal)['timing'] == 'on'
                assert b'Time: ' not in terminal.screen, terminal.screen
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
    local = project/'.transit'; local.mkdir()
    (local/'caller.seed').write_text('11'*32)
    (project/'.transitrc').unlink(); (home/'.transitrc').unlink(); home_server.unlink()
    identity = dict.fromkeys(('config', 'cli', 'minio', 'ursula', 'node', 'query_host'), [0]*32)
    definition = json.loads((Path(__file__).resolve().parents[1] / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition']
    record = dict(definition=definition, identity=identity, installation=[0]*16, root_public=[0]*32,
                  complete=True, genesis_observed=True, default_table_complete=True, provision=list(range(1, 15)))
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
           env=environment, cwd=project, contains=('query could not complete',))
    assert not installation.exists()
# Structured stderr is independent of result format. These are real binaries,
# including byte paths, late failures, nested source positions and output loss.
def machine(args, expected=1, data=b'', env=None, out=None):
    global CASES
    result = subprocess.run([CLI, '--diagnostics=json', *map(str,args)], input=data,
                            stdout=subprocess.PIPE if out is None else out, stderr=subprocess.PIPE,
                            timeout=10, env=ENV if env is None else env, cwd=ISOLATED.name)
    assert result.returncode == expected, (args,result.returncode,result.stderr)
    assert b'\x1b' not in result.stderr and b'private-must-not-appear' not in result.stderr, result.stderr
    records = [json.loads(line) for line in result.stderr.splitlines()]
    diagnostics = [item for item in records if 'code' in item]
    assert len(diagnostics) == 1, records
    diagnostic = diagnostics[0]
    assert diagnostic['code'] not in ('cli.diagnostic_unavailable','cli.internal_failure','file.internal_failure'), diagnostic
    assert diagnostic['definition'] == definition and len(result.stderr) < 32768, diagnostic
    assert diagnostic['outcome'] not in ('applied','rejected','cancelled'), diagnostic
    assert not any(action and action['kind'] in ('resume_exact','cancel_wait','cancel_mutation') for action in diagnostic['actions']), diagnostic
    CASES += 1
    return result,diagnostic,records

def facts(diagnostic):
    return {item['field']:item['value'] for item in diagnostic['facts'] if item}

result,detail,_ = machine(['private-must-not-appear'],2)
assert detail['code'] == 'cli.invalid_invocation' and facts(detail)['argument'] == {'unsigned':'2'}
assert detail['outcome'] == 'not_submitted' and not result.stdout
for route in ('console','app','mutate','catalog','query','file-query'):
    args = [route,'--bad=private-must-not-appear']
    _,detail,_ = machine(args,2)
    assert detail['code'] == 'cli.invalid_invocation', detail
with tempfile.TemporaryDirectory(prefix='transit-cli-json-') as directory:
    root = Path(directory)
    config = root/'console.json'
    seed = root/'caller.seed'; seed.write_text('2a'*32)
    config.write_text(json.dumps(dict(console,seed_file=str(seed))))
    args = ['console','--no-rc','--config',config,'--format','json']
    _,detail,_ = machine([*args,'-c','SELECT typo FROM items'])
    assert detail['code'] == 'sql.unknown_column' and facts(detail)['column'] == {'text':'typo'}
    assert detail['location']['offset'] == '7' and detail['outcome'] == 'not_submitted'
    script = root/'script.sql'
    text = '-- 東京\r\n.show\r\n  SELECT typo FROM items;\n'
    script.write_bytes(text.encode())
    _,detail,_ = machine([*args,'-f',script])
    location = detail['location']
    assert location['source'] == str(script) and location['statement'] == '2', location
    assert location['offset'] == str(text.encode().index(b'typo')) and location['line'] == '3' and location['byte_column'] == '10', location
    assert facts(detail)['completed_statements'] == {'unsigned':'1'}
    _,detail,records = machine(args,data=b'.timer on\nSELECT typo FROM items;\n')
    assert len(records) == 2 and records[1]['timing']['unit'] == 'ms', records
    assert detail['code'] == 'sql.unknown_column'
    for ddl,code,offset in [('CREATE TABLE items (id JSON PRIMARY KEY,value UTF8)','sql.unsupported_primary_key_type',51),
                            ('CREATE TABLE items (id INT64 NOT NULL,id UTF8 NULL)','sql.duplicate_column',51)]:
        sql = root/'create.sql'; sql.write_text(ddl)
        catalog = root/'catalog.json'; catalog.write_text(json.dumps(catalog_values))
        output = root/'must-not-exist.json'
        _,detail,_ = machine(['catalog','compile','--config',catalog,'--operation','1','--object','1','--namespace','1','--file',sql,'--output',output])
        assert detail['code'] == code and detail['location']['offset'] == str(offset), detail
        assert detail['location']['source'] == str(sql) and not output.exists()
    csv = root/'late.csv'; csv.write_text('id,value\n1,100\n2,bad\n')
    for limit in ('',' LIMIT 0',' LIMIT 1'):
        result,detail,_ = machine(['file-query','--format','csv','--sample-records','1','-c','SELECT * FROM input'+limit,csv])
        assert detail['code'] == 'file.invalid_literal' and detail['stage'] == 'decode', detail
        assert detail['location'] is None and facts(detail)['source_row'] == {'unsigned':'3'}
        assert facts(detail)['byte_offset'] == {'unsigned':'15'}
        assert facts(detail)['field_path'] == {'text':'/value'} and facts(detail)['supplied_value'] == {'text':'bad'}
        assert facts(detail)['completion'] == {'boolean':False} and facts(detail)['schema_origin'] == {'text':'inferred'}
        assert all('complete' not in row for row in map(json.loads,result.stdout.splitlines())), result.stdout
    csv.write_text('id,value\n1,9223372036854775807\n2,1\n')
    _,detail,_ = machine(['file-query','--format','csv','-c','SELECT SUM(value) FROM input',csv])
    assert detail['code'] == 'file.arithmetic_overflow' and facts(detail)['column'] == {'text':'value'}
    assert 'source_basis' in facts(detail) and facts(detail)['completion'] == {'boolean':False}
    csv.write_text('id,value\n1,100\n2,200\n')
    _,detail,_ = machine(['file-query','--format','csv','--max-records','1','-c','SELECT * FROM input',csv])
    assert detail['code'] == 'file.record_count_limit' and facts(detail)['limit'] == {'unsigned':'1'}
    assert facts(detail)['required'] == {'unsigned':'2'}
    assert 'measured minimum' in facts(detail)['constraint']['text']
    with open('/dev/full','wb') as output:
        _,detail,_ = machine(['file-query','--format','csv','-c','SELECT * FROM input',csv],out=output)
    assert detail['code'] == 'file.output_incomplete' and detail['stage'] == 'output'
    assert facts(detail)['completion'] == {'boolean':False}
    byte_path = root/os.fsdecode(b'bad-\xff.json')
    byte_path.write_text('{"version":')
    _,detail,_ = machine(['query',byte_path],2)
    assert detail['code'] == 'cli.invalid_configuration' and detail['location']['source_encoding'] == 'escaped_bytes', detail
    assert detail['location']['source'].endswith('bad-\\xff.json')
    # A long UTF-8 scalar preview cannot split a code point or destroy the cause.
    csv.write_text('id,value\n1,100\n2,'+'界'*50+'\n')
    _,detail,_ = machine(['file-query','--format','csv','--sample-records','1','-c','SELECT * FROM input',csv])
    assert detail['code'] == 'file.invalid_literal'
    preview = next(item for item in detail['facts'] if item and item['field']=='supplied_value')
    assert preview['availability'] == 'truncated' and preview['value']['text'] == '界'*42, preview
    # Every expected source/schema failure crosses the actual executable boundary.
    cases = [
        ('jsonl', b'\n', [], 'file.empty_json_record'),
        ('jsonl', b'{"id":1}\r', [], 'file.invalid_line_ending'),
        ('csv', b'id\r1\n', [], 'file.invalid_line_ending'),
        ('csv', b',value\n1,2\n', [], 'file.invalid_field_name'),
        ('csv', b'id,id\n1,2\n', [], 'file.duplicate_field'),
        ('csv', b'a'*256+b'\n1\n', [], 'file.invalid_field_name'),
        ('csv', b'a\x00b\n1\n', [], 'file.invalid_field_name'),
        ('csv', b'id,value,extra\n1,2,3\n', ['--max-fields','2'], 'file.field_count_limit'),
        ('csv', b','.join((str(i)+'x'*250).encode() for i in range(18))+b'\n', [], 'file.header_name_byte_limit'),
        ('csv', b'id\n123456789\n', ['--max-record-bytes','8'], 'file.record_byte_limit'),
        ('jsonl', b'{"id":1\n', [], 'file.invalid_json'),
        ('jsonl', b'{"id":1,"id":2}\n', [], 'file.duplicate_field'),
        ('jsonl', b'{"a":1,"b":2,"c":3}\n', ['--max-fields','2'], 'file.json_field_limit'),
        ('jsonl', b'{"a":'+b'['*17+b'1'+b']'*17+b'}\n', [], 'file.json_depth_limit'),
        ('jsonl', b'{"a":['+b','.join([b'1']*5000)+b']}\n', [], 'file.json_token_limit'),
        ('jsonl', json.dumps({str(i)+'x'*64:1 for i in range(100)}).encode()+b'\n', [], 'file.inference_name_limit'),
        ('jsonl', json.dumps({str(i):{'a':1,'b':2} for i in range(100)}).encode()+b'\n', [], 'file.inference_node_limit'),
        ('jsonl', b'{"a":'+b'['*15+b'1'+b']'*15+b'}\n', [], 'file.inference_depth_limit'),
    ]
    for format, content, options, code in cases:
        source = root/('bad.'+format); source.write_bytes(content)
        result,detail,_ = machine(['file-query','--format',format,*options,'-c','SELECT * FROM input',source])
        assert detail['code'] == code, (code,detail)
        assert not result.stdout and facts(detail)['completion'] == {'boolean':False}, (code,result.stdout)
        assert detail['stage'] == 'decode', detail
        if code == 'file.duplicate_field' and format == 'csv':
            assert facts(detail)['field_path'] == {'text':'id'} and facts(detail)['column'] == {'unsigned':'1'}
            assert facts(detail)['first_occurrence'] == {'unsigned':'0'}
        if code == 'file.header_name_byte_limit':
            assert facts(detail)['budget'] == {'text':'header_name_bytes'} and facts(detail)['limit'] == {'unsigned':'4096'}
            assert int(facts(detail)['required']['unsigned']) > 4096
        if code == 'file.json_field_limit':
            assert facts(detail)['required'] == {'unsigned':'3'} and facts(detail)['limit'] == {'unsigned':'2'}
        if code == 'file.record_byte_limit':
            assert facts(detail)['required'] == {'unsigned':'9'} and facts(detail)['limit'] == {'unsigned':'8'}
    # Token diagnostics retain original bytes and decoded nested member paths.
    lexical = root/'lexical.jsonl'
    lexical_cases = [
        ('{"雪":[{"a/b~":1,"a\\u002fb~":{"child":2}}]}'.encode(), 'file.duplicate_field', '/雪/0/a~1b~0', b'"a\\u002fb~"', b'"a/b~"'),
        (b'{"x":[1,truX]}', 'file.invalid_json', '/x/1', b'X', None),
        ('{"雪":"ok","x":truX}'.encode(), 'file.invalid_json', '/x', b'X', None),
        (b'{"x":"a\xff"}', 'file.invalid_utf8', None, b'\xff', None),
        (b'{"x":1', 'file.invalid_json', None, b'', None),
    ]
    for content,code,pointer,token,earlier in lexical_cases:
        lexical.write_bytes(content+b'\n')
        result,detail,_ = machine(['file-query','--format','jsonl','-c','SELECT * FROM input',lexical])
        observed = facts(detail)
        assert detail['code'] == code and not result.stdout, detail
        assert observed['completion'] == {'boolean':False}, detail
        if pointer is not None:
            assert observed['field_path'] == {'text':pointer}, detail
        offset = int(observed['byte_offset']['unsigned'])
        assert offset == (content.index(token) if token else len(content)), detail
        if earlier:
            assert observed['first_occurrence'] == {'unsigned':str(content.index(earlier))}, detail
    # A later source/record has file-local absolute byte evidence, including LIMIT 0.
    first_json = root/'first-json.jsonl'; first_json.write_bytes(b'{"ok":1}\n')
    prefix = b'{"ok":2}\n'
    bad = b'{"nested":[{"a":1,"\\u0061":2}]}'
    lexical.write_bytes(prefix+bad+b'\n')
    for limit in ('', ' LIMIT 0', ' LIMIT 1'):
        result,detail,_ = machine(['file-query','--format','jsonl','--mode','raw','-c','SELECT * FROM input'+limit,first_json,lexical])
        observed = facts(detail)
        assert detail['code'] == 'file.duplicate_field' and result.stdout, detail
        assert observed['object'] == {'text':str(lexical)} and observed['source_row'] == {'unsigned':'2'}, detail
        assert observed['field_path'] == {'text':'/nested/0/a'}, detail
        assert observed['byte_offset'] == {'unsigned':str(len(prefix)+bad.index(b'"\\u0061"'))}, detail
        assert observed['first_occurrence'] == {'unsigned':str(len(prefix)+bad.index(b'"a"'))}, detail
        assert observed['completion'] == {'boolean':False} and b'"complete":true' not in result.stdout, result.stdout
    lexical.write_bytes(b'\xef\xbb\xbf'+bad+b'\n')
    _,detail,_ = machine(['file-query','--format','jsonl','-c','SELECT * FROM input',lexical])
    assert facts(detail)['byte_offset'] == {'unsigned':str(3+bad.index(b'"\\u0061"'))}, detail
    assert facts(detail)['first_occurrence'] == {'unsigned':str(3+bad.index(b'"a"'))}, detail
    lexical.write_bytes(bad+b'\n')
    invoke(['file-query','--format','jsonl','-c','SELECT * FROM input',lexical],1,
           contains=('JSON path (JSON Pointer): "/nested/0/a"', 'Record byte offset (zero-based): 18', 'Earlier member byte offset in record (zero-based): 12'))
    # Discovery witnesses refer to input fields/indices and the first excess.
    discovery_file = root/'discovery.jsonl'
    discovery_cases = [
        ({'a':[[[[[[[[[[[[[[[1]]]]]]]]]]]]]]]}, 'file.inference_depth_limit', '/a'+'/0'*15, 'depth', 17, 16),
        ({f'{i:02d}'+'x'*253: 1 for i in range(17)}, 'file.inference_name_limit', '/16'+'x'*253, 'name_bytes', 4335, 4096),
    ]
    for content,code,pointer,dimension,required,limit in discovery_cases:
        discovery_file.write_text(json.dumps(content)+'\n')
        result,detail,_ = machine(['file-query','--format','jsonl','--mode','full','-c','SELECT * FROM input',discovery_file])
        observed = facts(detail)
        assert detail['code'] == code and not result.stdout, detail
        assert observed['field_path'] == {'text':pointer} and observed['schema_origin'] == {'text':'inferred'}, detail
        assert observed['budget'] == {'text':dimension} and observed['required'] == {'unsigned':str(required)} and observed['limit'] == {'unsigned':str(limit)}, detail
        assert observed['source_row'] == {'unsigned':'1'} and observed['byte_offset'] == {'unsigned':'0'}, detail
        assert 'complete: false' in observed['source_basis']['text'], detail
    earlier = root/'earlier-discovery.jsonl'
    earlier.write_text(json.dumps({f'l{i}':1 for i in range(128)})+'\n')
    discovery_file.write_text(json.dumps({f'r{i}':1 for i in range(128)})+'\n')
    result,detail,_ = machine(['file-query','--format','jsonl','--mode','full','-c','SELECT * FROM input',earlier,discovery_file])
    observed = facts(detail)
    assert detail['code'] == 'file.inference_node_limit' and not result.stdout, detail
    assert observed['object'] == {'text':str(discovery_file)} and observed['source_row'] == {'unsigned':'1'}, detail
    assert observed['field_path'] == {'text':'/r127'} and observed['required'] == {'unsigned':'257'} and observed['limit'] == {'unsigned':'256'}, detail
    assert 'entered 2 records' in observed['source_basis']['text'] and 'complete: false' in observed['source_basis']['text'], detail
    for bad_name in ('', 'nul\x00name', '界'*86):
        discovery_file.write_text(json.dumps({'outer/~':{bad_name:1}}, ensure_ascii=False)+'\n')
        result,detail,_ = machine(['file-query','--format','jsonl','-c','SELECT * FROM input',discovery_file])
        observed = facts(detail)
        assert detail['code'] == 'file.invalid_field_name' and not result.stdout, detail
        pointer = '/outer~1~0/'+bad_name
        actual = observed['field_path']['text']
        assert pointer.startswith(actual) and len(actual.encode()) <= 256, detail
        field = next(item for item in detail['facts'] if item and item['field'] == 'field_path')
        assert field['availability'] == ('truncated' if len(pointer.encode()) > 256 else 'provided'), detail
        assert observed['schema_origin'] == {'text':'inferred'}, detail
    for content,options,entered,complete in [('',[] ,0,True), ('{}\n',[],1,True), ('{}\n{"id":1}\n',['--sample-records','1'],1,False)]:
        discovery_file.write_text(content)
        result,detail,_ = machine(['file-query','--format','jsonl',*options,'-c','SELECT * FROM input',discovery_file])
        observed = facts(detail)
        assert detail['code'] == 'file.unresolved_schema' and not result.stdout, detail
        assert '--schema' in detail['message'] and '--mode raw' in detail['message'], detail
        assert f'entered {entered} records' in observed['source_basis']['text'] and f'complete: {str(complete).lower()}' in observed['source_basis']['text'], detail
        assert 'source_row' not in observed and 'byte_offset' not in observed and 'field_path' not in observed, detail
    missing_data = root/'absent-input.csv'
    result,detail,_ = machine(['file-query','--format','csv','-c','SELECT * FROM input',missing_data])
    assert detail['code'] == 'file.source_unavailable' and detail['cause'] == 'NOENT', detail
    assert facts(detail)['object'] == {'text':str(missing_data)} and not result.stdout, detail
    missing_schema = root/'absent-schema.json'
    result,detail,_ = machine(['file-query','--format','csv','--mode','explicit','--schema',missing_schema,'-c','SELECT * FROM input',csv])
    assert detail['code'] == 'file.schema_read_unavailable' and detail['stage'] == 'input' and detail['cause'] == 'FileNotFound', detail
    assert facts(detail)['object'] == {'text':str(missing_schema)} and not result.stdout, detail
    assert [a['kind'] for a in detail['actions'] if a] == ['retry_read'], detail
    schema = root/'schema.json'
    schema_definition = 'transit.fuze.types.v1.2026-09-30'
    def schema_value(type):
        return {'definition':schema_definition,'type':{'structure':[{'name':'id','type':type}]}}
    csv.write_text('id\n1\n')
    schemas = [
        ('{', 'file.invalid_json'),
        ('{}', 'file.invalid_schema_descriptor'),
        (json.dumps({'definition':'foreign','type':{'structure':[{'name':'id','type':{'int64':{}}}]}}), 'file.incompatible_type_definition'),
        (json.dumps(schema_value({'unknown':{}})), 'file.invalid_schema_descriptor'),
        (json.dumps(schema_value({'decimal':{'precision':39,'scale':0}})), 'file.invalid_decimal_type'),
        (json.dumps(schema_value({'structure':[{'name':'x','type':{'int64':{}}}]})), 'file.unsupported_csv_type'),
        (' '*65537, 'file.schema_file_limit'),
    ]
    for content,code in schemas:
        schema.write_text(content)
        result,detail,_ = machine(['file-query','--format','csv','--mode','explicit','--schema',schema,'-c','SELECT * FROM input',csv])
        assert detail['code'] == code and detail['stage'] == 'decode', detail
        assert not result.stdout
        if code != 'file.unsupported_csv_type':
            assert facts(detail)['object']['text'] == str(schema), detail
        else:
            assert facts(detail)['field_path'] == {'text':'id'} and facts(detail)['actual_type'] == {'text':'structure'}
    for content,pointer in [('{"definition":"'+schema_definition+'","type":{"structure":[{"name":"界","type":{"int64":{}},"nullable":truX}]}}', '/type/structure/0/nullable'), ('{"definition":', None)]:
        schema.write_text(content)
        result,detail,_ = machine(['file-query','--format','csv','--mode','explicit','--schema',schema,'-c','SELECT * FROM input',csv])
        observed = facts(detail)
        assert detail['code'] == 'file.invalid_json' and not result.stdout, detail
        assert observed['object'] == {'text':str(schema)}, detail
        if pointer:
            assert observed['field_path'] == {'text':pointer}, detail
        assert observed['byte_offset'] == {'unsigned':str(content.encode().index(b'X') if pointer else len(content))}, detail
    # Decode failures identify the actual JSON member before semantic validation.
    member_cases = [
        ({'decimal':{'precision':3}}, 'file.invalid_schema_descriptor', '/decimal/scale', 'integer from 0 to 255', None),
        ({'decimal':{'precision':256,'scale':0}}, 'file.scalar_out_of_range', '/decimal/precision', 'integer from 0 to 255', '256'),
        ({'decimal':{'precision':True,'scale':0}}, 'file.invalid_schema_descriptor', '/decimal/precision', 'integer from 0 to 255', 'true'),
        ({'timestamp':'local'}, 'file.invalid_schema_descriptor', '/timestamp', 'one of: civil, utc', '"local"'),
        ({'mystery/~':{}}, 'file.invalid_schema_descriptor', '/mystery~1~0', 'declared logical type tag', 'mystery/~'),
        ({'list':{'type':{'int64':{}},'nullable':1}}, 'file.invalid_schema_descriptor', '/list/nullable', 'boolean', '1'),
        ({'array':{'length':1,'element':{}}}, 'file.invalid_schema_descriptor', '/array/element/type', 'object containing exactly one logical type tag', None),
        ({'structure':[{'name':'x','type':{'int64':{}},'extra/~':True}]}, 'file.invalid_schema_descriptor', '/structure/0/extra~1~0', 'declared descriptor member', 'extra/~'),
    ]
    for kind,code,pointer,expected,supplied in member_cases:
        content = json.dumps(schema_value(kind), ensure_ascii=False).replace('"id"', '"界"')
        schema.write_text(content)
        result,detail,_ = machine(['file-query','--format','csv','--mode','explicit','--schema',schema,'-c','SELECT * FROM input',csv])
        observed = facts(detail)
        assert detail['code'] == code and detail['stage'] == 'decode' and not result.stdout, detail
        assert observed['field_path'] == {'text':'/type/structure/0/type'+pointer}, detail
        assert observed['expected_type'] == {'text':expected}, detail
        if supplied is not None:
            assert observed['supplied_value'] == {'text':supplied}, detail
            offset = int(observed['byte_offset']['unsigned'])
            token = json.dumps(supplied, ensure_ascii=False) if expected.startswith('declared ') else supplied
            assert content.encode()[offset:].startswith(token.encode()), detail
        else:
            assert 'supplied_value' not in observed and 'byte_offset' not in observed, detail
    content = json.dumps(schema_value({'decimal':{'precision':3,'scale':0}})).replace('"precision": 3','"precision": 3, "precisi\\u006fn": 4')
    schema.write_text(content)
    result,detail,_ = machine(['file-query','--format','csv','--mode','explicit','--schema',schema,'-c','SELECT * FROM input',csv])
    observed = facts(detail)
    assert detail['code'] == 'file.invalid_schema_descriptor' and detail['cause'] == 'DuplicateField' and not result.stdout, detail
    assert observed['field_path'] == {'text':'/type/structure/0/type/decimal/precision'} and observed['supplied_value'] == {'text':'precision'}, detail
    assert content[int(observed['byte_offset']['unsigned']):].startswith('"precisi\\u006fn"'), detail
    # Recursive descriptor evidence survives release of the JSON parser owner.
    descriptor_cases = [
        ({'decimal':{'precision':0,'scale':0}}, 'file.invalid_decimal_type', '/decimal/precision', {'actual_count':{'unsigned':'0'}, 'limit':{'unsigned':'38'}, 'supplied_value':{'text':'decimal(0,0)'}}),
        ({'decimal':{'precision':3,'scale':4}}, 'file.invalid_decimal_type', '/decimal/scale', {'actual_count':{'unsigned':'4'}, 'limit':{'unsigned':'3'}, 'supplied_value':{'text':'decimal(3,4)'}}),
        ({'array':{'length':0,'element':{'type':{'int64':{}}}}}, 'file.invalid_array_length', '/array/length', {'actual_count':{'unsigned':'0'}}),
        ({'structure':[]}, 'file.invalid_schema_field_count', '/structure', {'actual_count':{'unsigned':'0'},'limit':{'unsigned':'255'}}),
        ({'tagged_union':[{'name':'x','type':{'int64':{}},'optional':True}]}, 'file.invalid_union_type', '/tagged_union/0/optional', {'supplied_value':{'text':'true'}}),
        ({'map':{'key':{'json':{}},'value':{'type':{'int64':{}}}}}, 'file.invalid_map_key_type', '/map/key', {'supplied_value':{'text':'json'}}),
        ({'structure':[{'name':'a/~','type':{'int64':{}}},{'name':'a/~','type':{'int8':{}}}]}, 'file.duplicate_field', '/structure/1/name', {'supplied_value':{'text':'a/~'},'column':{'unsigned':'1'},'first_occurrence':{'unsigned':'0'}}),
    ]
    for name in ('', 'a\x00b', '界'*86):
        descriptor_cases.append(({'structure':[{'name':name,'type':{'int64':{}}}]}, 'file.invalid_field_name', '/structure/0/name', {}))
    # Every recursive edge points at the descriptor, not an imagined row path.
    for nested,pointer in [
        (lambda t: {'list':{'type':t}}, '/list/type'),
        (lambda t: {'array':{'length':1,'element':{'type':t}}}, '/array/element/type'),
        (lambda t: {'map':{'key':{'utf8':{}},'value':{'type':t}}}, '/map/value/type'),
        (lambda t: {'map':{'key':t,'value':{'type':{'utf8':{}}}}}, '/map/key'),
        (lambda t: {'tagged_union':[{'name':'nested','type':t}]}, '/tagged_union/0/type'),
    ]:
        descriptor_cases.append((nested({'decimal':{'precision':39,'scale':0}}), 'file.invalid_decimal_type', pointer+'/decimal/precision', {'supplied_value':{'text':'decimal(39,0)'}}))
    for kind,code,pointer,expected in descriptor_cases:
        schema.write_text(json.dumps(schema_value(kind)))
        result,detail,_ = machine(['file-query','--format','csv','--mode','explicit','--schema',schema,'-c','SELECT * FROM input',csv])
        assert detail['code'] == code and detail['stage'] == 'decode' and not result.stdout, detail
        observed = facts(detail)
        assert observed['field_path'] == {'text':'/type/structure/0/type'+pointer}, detail
        assert observed['completion'] == {'boolean':False} and 'constraint' in observed
        assert all(observed[key] == value for key,value in expected.items()), detail
        assert [a['kind'] for a in detail['actions'] if a] == ['correct_input'], detail
    schema.write_text(json.dumps({'definition':schema_definition,'type':{'int64':{}}}))
    _,detail,_ = machine(['file-query','--format','csv','--mode','explicit','--schema',schema,'-c','SELECT * FROM input',csv])
    assert detail['code'] == 'file.invalid_schema' and facts(detail)['field_path'] == {'text':'/type'}
    assert facts(detail)['supplied_value'] == {'text':'int64'}
    # Distinct default descriptor budgets, including their measured first excess.
    many_fields = [{'name':str(i),'type':{'int64':{}}} for i in range(255)]
    many_fields[0]['type'] = {'list':{'type':{'int64':{}}}}
    long_names = [{'name':str(i)+'x'*253,'type':{'int64':{}}} for i in range(17)]
    deep = {'int64':{}}
    for _ in range(16): deep = {'list':{'type':deep}}
    for kind,dimension,required,limit in [({'structure':many_fields},'nodes',257,256), ({'structure':long_names},'name_bytes',4325,4096), (deep,'depth',17,16)]:
        schema.write_text(json.dumps({'definition':schema_definition,'type':kind}))
        result,detail,_ = machine(['file-query','--format','csv','--mode','explicit','--schema',schema,'-c','SELECT * FROM input',csv])
        assert detail['code'] == 'file.schema_limit' and not result.stdout, detail
        observed = facts(detail)
        assert observed['budget'] == {'text':dimension} and observed['required'] == {'unsigned':str(required)} and observed['limit'] == {'unsigned':str(limit)}, detail
        assert not any(detail['actions']), detail
    for option,value,explanation in [('--max-record-bytes','65537','65536'),('--max-fields','129','128'),('--delimiter','\t','printable ASCII')]:
        _,detail,_ = machine(['file-query','--format','csv',option,value,'-c','SELECT * FROM input',csv],2)
        assert facts(detail)['option'] == {'text':option} and explanation in detail['message'], detail
    # Escaping can exceed the output bound even with a bounded input record.
    csv.write_bytes(b'id\n'+b'\x00'*50000+b'\n')
    result,detail,_ = machine(['file-query','--format','csv','--mode','raw','-c','SELECT * FROM input',csv])
    assert detail['code'] == 'file.output_record_limit' and detail['stage'] == 'output', detail
    assert facts(detail)['budget'] == {'text':'output_record_bytes'} and facts(detail)['limit'] == {'unsigned':'262144'}
    assert int(facts(detail)['required']['unsigned']) > 262144
    assert len(result.stdout.splitlines()) == 1 and b'"complete":{' not in result.stdout
    # Local spool failures cannot be mistaken for a bad source path or stdout.
    csv.write_text('id\n1\n')
    missing_spool = root/'missing-spool'
    _,detail,_ = machine(['file-query','--format','csv','-c','SELECT * FROM input',csv],env=dict(ENV,TMPDIR=str(missing_spool)))
    assert detail['code'] == 'file.capture_storage_unavailable' and detail['stage'] == 'input', detail
    assert facts(detail)['scope'] == {'text':str(missing_spool)} and facts(detail)['operation'] == {'text':'capture_directory'}
    # Valid gzip envelope around a reserved DEFLATE block type.
    compressed = root/'invalid.gz'
    compressed.write_bytes(bytes.fromhex('1f8b0800000000000003070000000000000000'))
    _,detail,_ = machine(['file-query','--format','csv','--gzip','-c','SELECT * FROM input',compressed])
    assert detail['code'] == 'file.invalid_deflate' and detail['cause'] == 'InvalidBlockType', detail
    # Record positions are local to the actual failing file, including headers.
    csv.write_text('id\n1\n')
    later = root/'later.csv'; later.write_text('id,id\n2,3\n')
    _,detail,_ = machine(['file-query','--format','csv','-c','SELECT * FROM input',csv,later])
    assert detail['code'] == 'file.duplicate_field' and facts(detail)['object'] == {'text':str(later)}
    assert facts(detail)['source_row'] == {'unsigned':'1'} and facts(detail)['byte_offset'] == {'unsigned':'0'}
    # Fixed Arrow encoding capacity is distinct from a downstream write failure.
    csv.write_bytes(b'id\n'+b'x'*65530+b'\n')
    result,detail,_ = machine(['file-query','--format','csv','--mode','raw','--output','arrow','-c','SELECT * FROM input',csv])
    assert detail['code'] == 'file.arrow_segment_limit' and detail['stage'] == 'output', detail
    assert facts(detail)['budget'] == {'text':'arrow_segment_bytes'} and facts(detail)['limit'] == {'unsigned':'65536'}
    assert result.stdout and facts(detail)['completion'] == {'boolean':False}
    for content,description in [(b'id\n"unfinished', 'closing quote'), (b'id\nwrong"quote\n', 'CSV quoting is malformed'), (b'id\n\xff\n', 'invalid UTF-8')]:
        csv.write_bytes(content)
        invoke(['file-query','--format','csv','-c','SELECT * FROM input',csv],1,contains=(description,))
    # Successful stdout remains byte-identical in the opt-in mode.
    csv.write_text('id,value\n1,100\n')
    arguments = ['file-query','--format','csv','-c','SELECT * FROM input',str(csv)]
    plain = subprocess.run([CLI,*arguments],capture_output=True,env=ENV,check=True)
    structured = subprocess.run([CLI,'--diagnostics=json',*arguments],capture_output=True,env=ENV,check=True)
    assert structured.stdout == plain.stdout and not structured.stderr
    CASES += 1
print(f'CLI diagnostics passed: {CASES} real command cases; no configuration or credential disclosure, stdout contamination or provisioning.')
