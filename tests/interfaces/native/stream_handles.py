"""Independent SGH1/SPH1 byte fixtures; no production encoder is invoked."""
import struct


def encode(value):
    group_only = 'group' in value
    receipt = None if group_only else value['receipt']
    target = value['group']['target'] if group_only else receipt['request']['target']
    group = value['group']['group'] if group_only else receipt['request']['group']
    interpretation = target['interpretation']
    obj = interpretation['object']
    scope = obj['scope']
    output = (b'SGH1' if group_only else b'SPH1') + bytes.fromhex(value['definition'])
    output += struct.pack('<6Q', scope['realm'], scope['resource'], scope['catalog'], obj['branch'], obj['object'], interpretation['revision'])
    output += bytes(interpretation['digest']) + struct.pack('<I3Q', target['partition'], group['id'], group['generation'], group['principal'])
    if group_only:
        return output + struct.pack('<Q', value['group']['next'])
    request, cut = receipt['request'], receipt['cut']
    output += struct.pack('<2QB', request['operation']['operation'], request['from'], request['until'] is not None)
    if request['until'] is not None:
        output += struct.pack('<Q', request['until'])
    output += bytes([request['timestamp'] is not None])
    if request['timestamp'] is not None:
        output += struct.pack('<2q', request['timestamp']['from_us'], request['timestamp']['until_us'])
    output += struct.pack('<5Q', cut['accepted']['partition'], cut['accepted']['next_lsn'], cut['retained_from'], cut['next'], receipt['source']['bytes'])
    output += bytes(receipt['source']['sha256'])
    progress = value['progress']
    output += bytes(['interval' in progress])
    cursors = [progress['interval']['first'], progress['interval']['last']] if 'interval' in progress else [progress['exhausted']]
    for cursor in cursors:
        coverage = cursor['coverage']
        output += struct.pack('<2QB', coverage['through'], coverage['rows'], coverage['complete']) + bytes(cursor['authentication'])
    return output
