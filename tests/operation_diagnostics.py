#!/usr/bin/env python3
"""Native test callers: private artifacts, source bounds and diagnostic evidence."""
import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

CLI = str(Path(sys.argv[1]).resolve())
ENV = {key: value for key, value in os.environ.items() if not key.startswith('TRANSIT_')}
CASES = 0
ISOLATED = tempfile.TemporaryDirectory(prefix='transit-cli-environment-')
ENV['HOME'] = ISOLATED.name


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



definition = json.loads((Path(__file__).resolve().parents[1] / "contracts/transit-v1.schema.json").read_text())["x-transit"]["definition"]
def machine(args, expected=1, data=b'', env=None, out=None):
    global CASES
    result = subprocess.run([CLI, '--structured', *map(str,args)], input=data,
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


with tempfile.TemporaryDirectory(prefix='transit-file-evidence-') as directory:
    root = Path(directory)
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
    structured = subprocess.run([CLI,'--structured',*arguments],capture_output=True,env=ENV,check=True)
    assert structured.stdout == plain.stdout and not structured.stderr
    CASES += 1
print(f'Native helper evidence passed: {CASES} artifact and file cases.')
