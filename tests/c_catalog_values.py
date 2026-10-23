"""Faults at the installed C/C++ SDK's real native ABI boundary.

The forwarding library injects replies, not durable authority. Disk-backed
admission/replay is separately qualified by typed_table_native.py.
"""
import copy
import json
import jsonschema
import os
from pathlib import Path
import select
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


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
    if (action == "{\\"capabilities\\":{}}") return actual(arg0, arg1, arg2, arg3);
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
    shutil.copy2(ROOT / 'tests/c_catalog_values.cpp', source)
    binary = target / 'consumer'
    subprocess.run(['zig', 'c++', '-std=c++17', '-Wall', '-Wextra', '-Werror', source, *flags, '-lpthread', '-o', binary], env=environment, cwd=target, check=True)
    source.unlink()
    (target / 'seed').write_text('1' * 64)
    child = subprocess.Popen([binary, target], cwd=target, env=environment, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    cases = 0

    def check(command, value, expected=0, mode='0', raw=False):
        nonlocal cases
        (target / 'response').write_text(value if raw else json.dumps(value))
        (target / 'mode').write_text(mode)
        child.stdin.write(command + '\n')
        child.stdin.flush()
        assert select.select([child.stdout], [], [], 30)[0], command + ' timed out'
        actual = child.stdout.readline()
        assert actual == str(expected) + '\n', (command, mode, expected, actual)
        cases += 1

    scope = dict(realm=46, resource=7, catalog=str(2**64-1))
    metadata = dict(scope=scope, namespace=1, object=str(2**64-1), revision=str(2**64-1), name='items', schema_fingerprint='ab'*32, principal=17, operation=str(2**64-1), admitted_input=9, commitment=dict(format=0x54434d01, length=200, digest=[171]*32))
    schema = dict(definition=definition, object=str(2**64-1), revision='1', next_column='3', columns=[dict(id='1', name='id', type={'int128': {}}, nullable=True, default=None, max_characters=None, encoding='rle', collation='none'),
        dict(id='2', name='text', type={'utf8': {}}, nullable=True, default=None, max_characters=None, encoding='ebcdic', collation='ebcdic_cp037')], primary_key=[])
    entry = dict(metadata=metadata, head=dict(revision='1', rows='0', pending='0'))
    current = dict(entry, schema=schema, authorization=101)
    page = dict(resource_revision=9, entries=[entry]+[None]*7, next=dict(definition=definition, scope=scope, resource_revision=9, after_object=str(2**64-1)))
    profile = dict(database_domain=1, schema_domain=2, table_domain=3, database=4, initial_schema_authority=5, initial_schema=1)
    subject = dict(principal=17, login_role=23, role=23, credential_epoch=1, audience=3, context=[171]*32)
    description = dict(configuration=dict(scope=scope, owner=3, administrator=0, table_limits=dict(record_bytes=4096, staging_bytes="8192", staging_records=64), authority=profile, database_name="fixture"), subject=subject, authorization_revision=9, resource_revision=2)
    jsonschema.Draft202012Validator(contract['schemas']['CatalogResult']).validate(dict(description=description))
    jsonschema.Draft202012Validator(contract['schemas']['CatalogResult']).validate(dict(definition=current))
    try:
        check('describe', dict(description=description))
        for change in [lambda v: v['subject'].update(principal=18), lambda v: v['subject'].update(role=24), lambda v: v['subject'].update(audience=4), lambda v: v['subject'].update(credential_epoch=0), lambda v: v['subject'].update(context=[171]*31), lambda v: v['configuration']['authority'].update(table_domain=2), lambda v: v['configuration'].pop('authority')]:
            bad = copy.deepcopy(description); change(bad); check('describe', dict(description=bad), 4)
        check('lookup', dict(definition=current))
        check('cpp_lookup', dict(definition=current))
        check('wrong_name', dict(definition=current), 4)
        check('history', dict(historical=dict(metadata=metadata, schema=schema)))
        check('wrong_history', dict(historical=dict(metadata=metadata, schema=schema)), 4)
        check('lookup', dict(definition=None))
        check('history', dict(historical=None))
        for change in [lambda v: v['metadata'].update(scope=dict(scope, catalog='1')),
                       lambda v: v['metadata'].update(revision='01'),
                       lambda v: v['metadata'].update(namespace=2),
                       lambda v: v.pop('authorization'),
                       lambda v: v['metadata'].pop('commitment'),
                       lambda v: v['metadata']['commitment'].update(format=0),
                       lambda v: v['metadata']['commitment'].update(length=0),
                       lambda v: v['metadata']['commitment'].update(length=445),
                       lambda v: v['metadata']['commitment'].update(digest=[171]*31),
                       lambda v: v['schema'].update(definition='0'*64),
                       lambda v: v['schema'].pop('definition'),
                       lambda v: v['schema']['columns'][0].pop('encoding'),
                       lambda v: v['schema']['columns'][0].pop('collation'),
                       lambda v: v['schema']['columns'][0].update(encoding='invented'),
                       lambda v: v['schema']['columns'][0].update(collation='invented'),
                       lambda v: v.update(extra=True)]:
            bad = copy.deepcopy(current); change(bad); check('lookup', dict(definition=bad), 4)
        check('lookup', '{"definition":null,"definition":null}', 4, raw=True)
        check('list', dict(page=page))
        check('list_next', dict(page=page), 4)
        check('empty_next', dict(page=dict(page, entries=[None]*8, next=dict(page['next'], after_object='9'))))
        for change in [lambda v: v.update(entries=[None]*7),
                       lambda v: v.update(entries=[None, entry]+[None]*6),
                       lambda v: v.update(entries=[entry, entry]+[None]*6),
                       lambda v: v['next'].update(after_object='1'),
                       lambda v: v['next'].update(resource_revision=10),
                       lambda v: v['next'].pop('definition')]:
            bad = copy.deepcopy(page); change(bad); check('list', dict(page=bad), 4)
        intent = dict(reference=dict(definition=definition, digest='00'*32), scope=scope, owner=3, principal=17, operation='10', namespace='100', object='1', kind='insert')
        compiled = dict(intent=intent, saved=dict(definition=definition, bytes='ab'*300000))
        check('prepare', dict(compiled=compiled))
        action = json.loads((target / 'captured').read_bytes())
        assert len(json.dumps(action)) > 600000
        for command, kind in [('physical_create', 'create'), ('physical_alter', 'alter')]:
            check(command, dict(compiled=dict(compiled, intent=dict(intent, kind=kind))))
            action = json.loads((target / 'captured').read_bytes())['prepare']['action']
            if kind == 'create':
                column = action['create']['schema']['columns'][0]
                assert column['encoding'] == 'ebcdic' and column['collation'] == 'ebcdic_cp037'
            else:
                assert action['alter']['change'] == dict(physical=dict(column='1', encoding='fsst', collation='ascii_ci'))
        calls = (target / 'calls').read_bytes()
        check('physical_invalid', dict(compiled=compiled), 1)
        assert (target / 'calls').read_bytes() == calls, 'invalid physical tag crossed the native boundary'
        for key in ('owner', 'principal', 'operation', 'namespace', 'object', 'kind'):
            bad = copy.deepcopy(compiled)
            bad['intent'][key] = 18 if key in ('owner', 'principal') else 'update' if key == 'kind' else '11'
            check('prepare', dict(compiled=bad), 4)
        calls = (target / 'calls').read_bytes()
        check('oversize', dict(compiled=compiled), 1)
        assert (target / 'calls').read_bytes() == calls, 'oversized action crossed the native boundary'
        for raw in ('', '{', '{"receipt":{"position":"1"}}', '{"receipt":{"position":7},"extra":true}'):
            check('submit', raw, 16, raw=True)
        check('submit', dict(receipt=dict(position=7)), 16, mode='huge')
        check('submit', dict(err='Uncertain'), 16, mode='6')
        check('submit', dict(err='CatalogDenied'), 7, mode='4')
        check('submit', dict(receipt=dict(position=7)))
        check('cpp_submit', dict(receipt=dict(position='1')), 16)
        check('cpp_submit', dict(receipt=dict(position=7)))
        check('block', dict(receipt=dict(position=7)), mode='block')
        child.stdin.write('close\n'); child.stdin.flush()
        assert child.wait(timeout=10) == 0
    finally:
        (target / 'release').write_text('1')
        if child.poll() is None: child.kill(); child.wait(timeout=10)
        child.stdin.close(); child.stdout.close()
        (target / 'seed').unlink()
    print(json.dumps(dict(profile='installed-c-cpp-catalog-boundary', cases=cases)))
