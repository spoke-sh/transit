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
for invalid in ('null', '{}', '[{"utf8": "private-must-not-appear", "uint64":"1"}]',
                '[{"uint64":1}]', '[{"boolean":true},{"boolean":true},{"boolean":true},{"boolean":true}]',
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
assert capabilities['create_table'] and capabilities['conditional_policy'] and capabilities['max_saved_bytes'] == 8192
invoke(['catalog', 'private-must-not-appear'], contains=('unknown catalog subcommand', 'argument 2'))
for mode in ('describe', 'lookup', 'definition', 'list', 'compile', 'prepare-initialize', 'prepare-create', 'prepare-policy', 'submit', 'observe', 'disposition', 'status'):
    invoke(['catalog', mode], contains=(f'Usage: transit catalog {mode}', '--config is required'))
    invoke(['catalog', mode, '--help'], 0, (f'Usage: transit catalog {mode}', 'Only submit sends a command'))
    invoke(['catalog', mode, '--config', 'private-must-not-appear', '--help'], 0)
    invoke(['catalog', mode, '--help', '--config'], stderr='error: --config requires a file path\n')
    invoke(['catalog', mode, '--help', '--unknown=private-must-not-appear'], contains=('argument 4',))
    invoke(['catalog', mode, '--config', 'one', '--config', 'two'], stderr='error: --config can only be specified once\n')
    invoke(['catalog', mode, '--help', '--help'], stderr='error: --help can only be specified once\n')
for mode, flag in [('capabilities', '--config'), ('submit', '--output'), ('describe', '--file'), ('status', '--operation'), ('lookup', '--file'), ('definition', '--name'), ('list', '--revision')]:
    invoke(['catalog', mode, flag, 'private-must-not-appear'], contains=(flag + ' is not supported',))
for flag in ('--operation', '--object'):
    for value in ('0', '00', '+1', '-1', '01', '18446744073709551616'):
        invoke(['catalog', 'compile', flag, value], contains=('canonical positive uint64',))
for value in ('0', '01', '4294967296'):
    invoke(['catalog', 'compile', '--table', value], contains=('canonical integer from 1 through 4294967295',))
for mode in ('observe', 'disposition'):
    for value in ('0', '01', '9007199254740992'):
        invoke(['catalog', mode, '--input', value], contains=('canonical positive native position',))
invoke(['catalog', 'lookup', '--config', 'missing'], contains=('--name is required',))
invoke(['catalog', 'definition', '--config', 'missing'], contains=('--object is required',))
invoke(['catalog', 'definition', '--config', 'missing', '--object', '1'], contains=('--revision is required',))
for value in ('1name', 'with space', 'name.with.dot', 'abcdefghijklmnopq', 'caf\u00e9'):
    invoke(['catalog', 'lookup', '--name', value], contains=('1 through 16 ASCII',))
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
    compile_args = ['catalog', 'compile', '--config', catalog_config, '--operation', '18446744073709551615', '--object', '18446744073709551615', '--table', '4294967295', '--file', sql, '--output', compiled_path]
    catalog_config.write_text(json.dumps(catalog_values))
    compiled = json.loads(invoke(compile_args, 0).stdout)
    assert json.loads(compiled_path.read_bytes()) == compiled
    assert compiled_path.stat().st_mode & 0o777 == 0o600
    assert compiled['compiled']['request']['operation'] == '18446744073709551615'
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
    invalid_compiled['compiled']['request']['name'] = 'other'
    bad_compiled.write_text(json.dumps(invalid_compiled))
    for mode in ('prepare-create', 'status'):
        args = ['catalog', mode, '--config', catalog_config, '--file', bad_compiled]
        if mode == 'prepare-create': args += ['--output', root / 'must-not-exist.json']
        invoke(args, 1, ('CatalogArtifactMismatch',))
    invalid_compiled = copy.deepcopy(compiled)
    canonical = bytearray.fromhex(invalid_compiled['compiled']['canonical'])
    canonical[5] ^= 1  # Foreign current-definition bytes must never be adopted.
    invalid_compiled['compiled']['canonical'] = canonical.hex()
    bad_compiled.write_text(json.dumps(invalid_compiled))
    invoke(['catalog', 'status', '--config', catalog_config, '--file', bad_compiled], 1, ('IncompatibleDefinition',))
    invalid_compiled = copy.deepcopy(compiled)
    invalid_compiled['compiled']['request']['table'] = '1'
    bad_compiled.write_text(json.dumps(invalid_compiled))
    invoke(['catalog', 'status', '--config', catalog_config, '--file', bad_compiled], contains=('artifact', 'invalid or missing field'))
    bad_prepared = root / 'bad-catalog-prepared.json'
    bad_prepared.write_text('{"prepared":null}')
    invoke(['catalog', 'submit', '--config', catalog_config, '--file', bad_prepared], contains=('artifact', 'invalid or missing field'))
    bad_prepared.write_text('{"prepared":"{}"}')
    invoke(['catalog', 'submit', '--config', catalog_config, '--file', bad_prepared], 1, ('InvalidCatalogPrepared',))
    # Entire saved pages, including mandatory definition and continuation
    # consistency, validate before reading the missing signing credential.
    fixture = Path(__file__).resolve().parents[1] / 'packages/zig/transit-catalog/src/fixtures/catalog-neutral-v1.json'
    page = json.loads(fixture.read_text())['page']
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
    for malformed in ('hole', 'scope', 'revision', 'name'):
        invalid_page = copy.deepcopy(page)
        if malformed == 'hole': invalid_page['entries'][1], invalid_page['entries'][0] = invalid_page['entries'][0], None
        elif malformed == 'scope': invalid_page['next']['scope']['catalog'] = '1'
        elif malformed == 'revision': invalid_page['next']['resource_revision'] += 1
        else: invalid_page['next']['after'] = 'other'
        page_path.write_text(json.dumps(dict(page=invalid_page)))
        invoke(page_args, 1, ('InvalidCatalogPage',))
    invalid_page = copy.deepcopy(page)
    invalid_page['entries'][0]['object'] = '01'
    page_path.write_text(json.dumps(dict(page=invalid_page)))
    invoke(page_args, 1, ('InvalidCatalogInteger',))
    page_path.write_text(json.dumps(dict(page=page)))
    invoke(page_args, contains=('cannot load the catalog signing credential',))
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
            ('INSERT INTO items VALUES (1, 100);', ('[syntax]', 'column 19', 'explicit column names', '.help INSERT')),
            ('INSERT INTO items (id, value) VALUES (1, 100);', ('no writer is configured', '.help INSERT')),
            ('SELECT * FROM items WHERE value = \'private-must-not-appear', ('SQL parse error', '^--- error here')),
            ('SELECT * /* private-must-not-appear', ('SQL parse error', '^--- error here')),
            ('CREATE KV items (UTF8);', ('[interface]', 'SQL publication of KV and Document definitions is unavailable', '.help SQL')),
            ('CREATE TABLE items (id INT64 NOT NULL, value INT64 NULL);', ('no catalog is configured', '.help CREATE TABLE')),
            ('CREATE TABLE items (id INT64, value INT64);', ('[binding]', 'INT64 NOT NULL', '.help CREATE TABLE')),
            ('CREATE TABLE items (id BOOLEAN);', ('[syntax]', 'INT64, BOOL, UTF8 or BINARY')),
            ('INSERT INTO items (id,value) VALUES (1,1),(2,2),(3,3),(4,4);', ('[limit]', 'MutationBatchTooLarge')),
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
                   env=environment, cwd=project, data=text+b'.show\n', stderr='Usage: .timing on|off\nInput: "<stdin>"; statement 1 starts at byte 0, line 1, byte column 1.\nPreviously completed commands: 0; their effects are not rolled back by this failure.\n')
    shown = invoke(['console', '--no-rc', '--config', connection], 0, env=environment, cwd=project,
                   data=b'.timing\ton\n.show\n')
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
            terminal.send('.timing on\r')
            terminal.expect('transit> .timing on\r\n')
            for statement, hint in timed_errors:
                terminal.send(statement+'\r')
                terminal.expect(hint)
                terminal.expect('ms)\r\n')
                display = ANSI.sub(b'', terminal.screen)
                assert display.count(b'Time: ') == 1, display
                assert display.index(b'error: ') < display.index(hint.encode()) < display.index(b'Time: '), display
            for text in ('.timing', '.timing off on'):
                terminal.send(text+'\r')
                terminal.expect('Usage: .timing on|off\r\n')
                terminal.send('.show\r')
                settings = read_show(terminal)
                assert settings['timing'] == 'on' and settings['format'] == format, settings
                assert b'Time: ' not in terminal.screen, terminal.screen
            terminal.send('.timing off\r')
            terminal.expect('transit> .timing off\r\n')
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
    plain_diagnostics = {}
    for format in ('table', 'json'):
        for color_env, colored in (
            ({'TERM': 'xterm-256color', 'NO_COLOR': '', 'CLICOLOR_FORCE': ''}, True),
            ({'TERM': 'xterm-256color', 'NO_COLOR': '1', 'CLICOLOR_FORCE': '1'}, False),
            ({'TERM': 'dumb', 'NO_COLOR': '', 'CLICOLOR_FORCE': '1'}, False),
        ):
            terminal = Terminal(CLI, connection, format=format, cwd=project, env=color_env)
            try:
                terminal.send('.timing on\r')
                terminal.expect('transit> .timing on\r\n')
                echo, _ = committed_display(terminal, '.timing on')
                assert (b'\x1b[36mtiming'+reset in echo) == colored, echo
                for statement, hint, category, cause in (
                    ('.unknown', '.help', None, 'UnknownConsoleCommand'),
                    ('CREATE TABLE people (id INT64, name BINARY);', '.help CREATE TABLE', 'binding', 'UnspecifiedNullability'),
                    ('CREATE TABLE people (id INTEGER, name TEXT);', '.help CREATE TABLE', 'syntax', 'UnsupportedDeclarationType'),
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
    definition = json.loads((Path(__file__).resolve().parents[1] / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition']
    record = dict(definition=definition, identity=identity, installation=[0]*16, root_public=[0]*32,
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
           env=environment, cwd=project, contains=('query could not complete',))
    assert not installation.exists()
print(f'CLI diagnostics passed: {CASES} real command cases; no configuration or credential disclosure, stdout contamination or provisioning.')
