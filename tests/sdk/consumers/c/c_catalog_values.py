"""Faults at the installed C/C++ SDK's real native ABI boundary.

The forwarding library injects replies, not durable authority. Installed
direct service recovery is separately qualified by direct_table_service.py.
"""
from runner.paths import ROOT
import copy
import json
import jsonschema
import os
from pathlib import Path
import select
import shutil
import subprocess



def run(target, prefix, flags, environment):
    target.mkdir()
    native = target / 'native'
    native.mkdir()
    shutil.copy2(prefix / 'lib/libtransit_client.so', native / 'libtransit_client.so')
    contract = json.loads((ROOT / 'packages/zig/transit-station-bindings/abi-v1.json').read_bytes())
    definition = contract['definition']
    # Forward handshake, diagnostic validation and open/close to the installed
    # native library. Only catalog replies and their buffers are substituted.
    lines = ['''#include <transit_station.h>
#include <dlfcn.h>
#include <fstream>
#include <iterator>
#include <string>
#include <thread>
#include <chrono>
#include <filesystem>
#include <unordered_set>
#include <mutex>
#include <cassert>
static std::mutex lock;
struct Reply { std::string bytes; bool huge; };
static std::unordered_set<const station_buffer *> replies;
static std::string read(const char *name) { std::ifstream f(name); return {std::istreambuf_iterator<char>(f), {}}; }
''', 'static void *library = dlopen(' + json.dumps(str(prefix / 'lib/libtransit_station.so')) + ', RTLD_NOW | RTLD_LOCAL);']
    custom = {
        'station_catalog_call': '''
    std::string action(reinterpret_cast<const char *>(arg1), arg2);
    if (action == "{\\"catalog\\":{\\"capabilities\\":{}}}") return actual(arg0, arg1, arg2, arg3);
    std::ofstream("captured", std::ios::binary) << action;
    std::ofstream("calls", std::ios::app) << "1\\n";
    const auto mode = read("mode");
    if (mode == "block") {
        std::ofstream("entered") << "1";
        while (!std::filesystem::exists("release")) std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
    auto *r = new Reply{read("response"), mode == "huge"};
    *arg3 = reinterpret_cast<station_buffer *>(r);
    { std::lock_guard<std::mutex> guard(lock); replies.insert(*arg3); }
    return mode == "4" ? 4 : mode == "6" ? 6 : 0;
''',
        'station_buffer_data': '''
    { std::lock_guard<std::mutex> guard(lock); if (replies.count(arg0)) return reinterpret_cast<const uint8_t *>(reinterpret_cast<const Reply *>(arg0)->bytes.data()); }
    return actual(arg0);
''',
        'station_buffer_size': '''
    { std::lock_guard<std::mutex> guard(lock); if (replies.count(arg0)) { const auto *v = reinterpret_cast<const Reply *>(arg0); return v->huge ? SIZE_MAX : v->bytes.size(); } }
    return actual(arg0);
''',
        'station_buffer_destroy': '''
    { std::lock_guard<std::mutex> guard(lock); if (replies.erase(arg0)) { delete reinterpret_cast<Reply *>(arg0); return; } }
    actual(arg0);
''',
    }
    for f in contract['functions']:
        args = ', '.join(f'{kind} arg{i}' for i, kind in enumerate(f['parameters'])) or 'void'
        types = ', '.join(f['parameters']) or 'void'
        call = ', '.join(f'arg{i}' for i in range(len(f['parameters'])))
        body = custom.get(f['name'], f'return actual({call});')
        lines.append(f'extern "C" {f["result"]} {f["name"]}({args}) {{ using F = {f["result"]} (*)({types}); static auto actual = reinterpret_cast<F>(dlsym(library, "{f["name"]}")); assert(actual); {body} }}')
    source = target / 'shim.cpp'
    source.write_text('\n'.join(lines))
    subprocess.run(['zig', 'c++', '-std=c++17', '-shared', '-fPIC', '-Wall', '-Wextra', '-Werror', f'-I{prefix / "include"}', source, '-ldl', '-lpthread', '-o', native / 'libtransit_station.so'], env=environment, cwd=target, check=True)
    source.unlink()
    source = target / 'consumer.cpp'
    shutil.copy2(ROOT / 'tests/sdk/consumers/c/c_catalog_values.cpp', source)
    binary = target / 'consumer'
    subprocess.run(['zig', 'c++', '-std=c++17', '-Wall', '-Wextra', '-Werror', source, *flags, '-lpthread', '-o', binary], env=environment, cwd=target, check=True)
    source.unlink()
    (target / 'seed').write_text('1' * 64)
    maximum = str(2**64-1)
    scope = dict(realm=46, resource=7, catalog=maximum)
    connection = dict(scope=scope, audience=3, branch='1', principal=17, role=23)
    obj = dict(scope=scope, branch='1', object=maximum)
    interpretation = dict(object=obj, revision='1', digest='ab'*32)
    stored = dict(interpretation=interpretation, content=dict(bytes='300', sha256='ab'*32), schema_fingerprint='cd'*32, retired=False)
    basis = dict(definition=definition, connection=connection, namespace=1, name='items', interpretation=stored)
    position = dict(partition=maximum, next_lsn=maximum)
    binding = dict(definition=definition, identity=dict(scope=scope, principal=17, operation='10'), target=obj, action='insert', expected_definition=interpretation, expected_data=None, intent='aa'*32, prerequisite=None)
    reference = dict(table=dict(definition=definition, connection=connection, namespace=1, binding=binding, content=dict(bytes='200', sha256='22'*32)))
    summary = dict(id=dict(definition=definition, digest='11'*32), namespace=1, binding=dict(table=binding))
    saved = dict(table=dict(definition=definition, namespace=1, bytes='ab'*300000))
    compiled = dict(summary=summary, saved=saved)
    schema = dict(definition=definition, object=maximum, revision='1', next_column='3', columns=[dict(id='1', name='id', type={'int128': {}}, nullable=True, default=None, max_characters=None, encoding='rle', collation='none'),
        dict(id='2', name='text', type={'utf8': {}}, nullable=True, default=None, max_characters=None, encoding='ebcdic', collation='ebcdic_cp037')], primary_key=[])
    metadata = dict(binding=basis, schema=schema, authorization=101, position=position, changed_lsn='3', row_count='9')
    entry = dict(interpretation=interpretation, namespace=1, name='items', position=position, changed_lsn='3')
    cursor = dict(definition=definition, connection=connection, selection=dict(tables=1), position=position, after='8')
    page = dict(position=position, entries=[entry]+[None]*7, next=dict(cursor, after=maximum), consistency='independent')
    observed = dict(rows=dict(committed=dict(binding=binding, resulting=stored, transaction=None, outcome=dict(position=position, matched='9', affected='9', live_rows='9'))))
    owner = dict(definition=definition, connection=connection, object=obj, operation=maximum)
    acquisition = dict(owner=owner, expected=position)
    snapshot = dict(owner=owner, content=dict(bytes='500', sha256='44'*32))
    retained = dict(snapshot=snapshot, interpretation=stored, accepted=position, changed_lsn='3', row_count='9', schema=schema, authority=dict(database=31, schema=32, table=33))
    authority = dict(database_domain=1, schema_domain=2, table_domain=3, stream_domain=31, queue_domain=32, database=4, initial_schema_authority=5, initial_schema=1)
    description = dict(configuration=dict(scope=scope, branch='1', partition=maximum, audience=3, authority=authority, database_name='fixture', initial_schema_name='public'), subject=dict(principal=17, login_role=23, role=23, credential_epoch=1, audience=3, context=[171]*32), policy_revision=9)
    for name, value in [('basis', basis), ('reference', reference), ('cursor', cursor), ('acquisition', acquisition), ('snapshot', snapshot)]:
        (target / (name + '.json')).write_text(json.dumps(value))
    validator = jsonschema.Draft202012Validator(contract['schemas']['CatalogResult'])
    for value in [dict(catalog=dict(description=description)), dict(metadata=metadata), dict(compiled=compiled), dict(catalog=dict(tables=page)), dict(observation=observed), dict(retention=dict(metadata=retained))]: validator.validate(value)
    child = subprocess.Popen([binary, target], cwd=target, env=environment, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    cases = 0
    def check(command, value, expected=0, mode='0', raw=False):
        nonlocal cases
        (target / 'response').write_text(value if raw else json.dumps(value))
        (target / 'mode').write_text(mode)
        child.stdin.write(command + '\n'); child.stdin.flush()
        assert select.select([child.stdout], [], [], 30)[0], command + ' timed out'
        actual = child.stdout.readline()
        assert actual == str(expected) + '\n', (command, mode, expected, actual)
        cases += 1
    try:
        check('describe', dict(catalog=dict(description=description)))
        for change in [lambda v: v['subject'].update(principal=18), lambda v: v['subject'].update(role=24), lambda v: v['subject'].update(audience=4), lambda v: v['subject'].update(credential_epoch=0), lambda v: v['subject'].update(context=[171]*31), lambda v: v['configuration']['authority'].update(table_domain=2), lambda v: v['configuration'].pop('authority')]:
            bad = copy.deepcopy(description); change(bad); check('describe', dict(catalog=dict(description=bad)), 4)
        check('lookup', dict(metadata=metadata)); check('cpp_lookup', dict(metadata=metadata)); check('wrong_name', dict(metadata=metadata), 4); check('lookup', dict(metadata=None))
        for change in [lambda v: v['binding']['connection']['scope'].update(catalog='1'), lambda v: v['binding']['interpretation']['interpretation'].update(revision='01'), lambda v: v['binding'].update(namespace=2), lambda v: v.pop('authorization'), lambda v: v['binding'].pop('definition'), lambda v: v['binding']['interpretation'].pop('content'), lambda v: v['binding']['interpretation']['content'].update(bytes='0'), lambda v: v['binding']['interpretation']['content'].update(sha256='00'*32), lambda v: v['schema'].update(definition='0'*64), lambda v: v['schema'].pop('definition'), lambda v: v['schema']['columns'][0].pop('encoding'), lambda v: v['schema']['columns'][0].pop('collation'), lambda v: v['schema']['columns'][0].update(encoding='invented'), lambda v: v['schema']['columns'][0].update(collation='invented'), lambda v: v.update(extra=True)]:
            bad = copy.deepcopy(metadata); change(bad); check('lookup', dict(metadata=bad), 4)
        check('lookup', '{"metadata":null,"metadata":null}', 4, raw=True)
        check('list', dict(catalog=dict(tables=page)))
        repeated = dict(entry, interpretation=dict(interpretation, object=dict(obj, object='8')))
        check('list_next', dict(catalog=dict(tables=dict(page, entries=[repeated]+[None]*7))), 4)
        check('empty_next', dict(catalog=dict(tables=dict(page, entries=[None]*8, next=dict(cursor, after='9')))))
        for change in [lambda v: v.update(entries=[None]*7), lambda v: v.update(entries=[None, entry]+[None]*6), lambda v: v.update(entries=[entry, entry]+[None]*6), lambda v: v['next'].update(after='1'), lambda v: v['next'].update(position=dict(position, next_lsn='10')), lambda v: v['next'].pop('definition')]:
            bad = copy.deepcopy(page); change(bad); check('list', dict(catalog=dict(tables=bad)), 4)
        check('prepare', dict(compiled=compiled)); action = json.loads((target / 'captured').read_bytes()); assert len(json.dumps(action)) > 600000 and action['prepare']['action']['mutate']['ingestion'] == 'bulk'
        for command, kind in [('physical_create', 'create'), ('physical_alter', 'alter')]:
            bound = dict(binding, action=kind, expected_definition=None if kind == 'create' else interpretation)
            check(command, dict(compiled=dict(compiled, summary=dict(summary, binding=dict(table=bound)))))
            action = json.loads((target / 'captured').read_bytes())['prepare']['action']
            if kind == 'create': assert action['create']['schema']['columns'][0]['encoding'] == 'ebcdic' and action['create']['schema']['columns'][0]['collation'] == 'ebcdic_cp037'
            else: assert action['alter']['change'] == dict(physical=dict(column='1', encoding='fsst', collation='ascii_ci'))
        for command in ('physical_invalid', 'oversize'):
            calls = (target / 'calls').read_bytes(); check(command, dict(compiled=compiled), 1); assert (target / 'calls').read_bytes() == calls
        for change in [lambda v: v['summary'].update(namespace=2), lambda v: v['summary']['binding']['table']['identity'].update(operation='11'), lambda v: v['summary']['binding']['table']['identity'].update(principal=18), lambda v: v['summary']['binding']['table']['target'].update(branch='2'), lambda v: v['summary']['binding']['table'].pop('prerequisite'), lambda v: v['summary']['binding']['table'].update(action='update'), lambda v: (v['summary']['binding']['table']['target'].update(object='1'), v['summary']['binding']['table']['expected_definition']['object'].update(object='1'))]:
            bad = copy.deepcopy(compiled); change(bad); check('prepare', dict(compiled=bad), 4)
        check('inspect', dict(observation=observed))
        bad = copy.deepcopy(observed); bad['rows']['committed']['binding']['identity']['operation'] = '11'
        check('inspect', dict(observation=bad), 4); check('execute', dict(observation=bad), 16); check('cpp_execute', dict(observation=bad), 16)
        for raw in ('', '{', '{"observation":{}}', json.dumps(dict(observation=observed, extra=True))): check('execute', raw, 16, raw=True)
        check('execute', dict(observation=observed), 16, mode='huge'); check('execute', dict(err='Uncertain'), 16, mode='6'); check('execute', dict(err='TableGrantDenied'), 7, mode='4')
        check('execute', dict(observation=observed)); check('cpp_execute', dict(observation=observed))
        check('acquire', dict(retention=dict(acquired=snapshot)))
        wrong = dict(snapshot, owner=dict(owner, operation='1')); check('acquire', dict(retention=dict(acquired=wrong)), 16)
        check('metadata', dict(retention=dict(metadata=retained)))
        check('metadata', dict(retention=dict(metadata=dict(retained, snapshot=wrong))), 4)
        check('release', dict(retention=dict(released=snapshot))); check('release', dict(retention=dict(released=wrong)), 16)
        check('restore_basis', basis); check('restore_reference', reference); check('restore_saved', saved)
        check('restore_basis', json.dumps(basis)[:-1] + ',"name":"other"}', 1, raw=True)
        for change in [lambda v: v['table'].pop('definition'), lambda v: v['table'].update(definition='0'*64), lambda v: v['table']['binding']['identity'].update(principal=18), lambda v: v['table']['binding'].pop('prerequisite')]:
            bad = copy.deepcopy(reference); change(bad); check('restore_reference', bad, 1)
        check('block', dict(observation=observed), mode='block')
        child.stdin.write('close\n'); child.stdin.flush(); assert child.wait(timeout=10) == 0
    finally:
        (target / 'release').write_text('1')
        if child.poll() is None: child.kill(); child.wait(timeout=10)
        child.stdin.close(); child.stdout.close(); (target / 'seed').unlink()
    print(json.dumps(dict(profile='installed-c-cpp-direct-catalog-boundary', cases=cases)))
