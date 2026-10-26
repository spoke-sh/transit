"""Independent application wire fixtures and bounded FIFO scheduling model.

This does not emulate Table storage or prove native authority. Domain steps are
scripted to use all four writes, exposing queue/continuation/restart mistakes.
"""
from runner.paths import ROOT
import copy
from dataclasses import asdict
import json
from pathlib import Path
import struct
import sys
from types import SimpleNamespace
from unittest.mock import patch



def fixtures():
    u64 = lambda n: struct.pack('<Q', n)
    query = lambda tag: b'TSQ\x01' + bytes([tag])
    insert = query(2) + struct.pack('<q', -(2**63)) + b'\0'
    meta = lambda h, t, r: b'TQM\x01' + u64(h) + u64(t) + bytes([r])
    work = lambda n, command: b'TQW\x01' + u64(n) + command
    outcome = lambda state, a, c, m, d, r: b'TQO\x01' + bytes([state]) + u64(a) + u64(c) + u64(m) + u64(d) + bytes([r])
    valid = [
        ('queue', meta(0, 0, 0)), ('queue', meta(1, 43, 1)), ('queue', meta(2**64-1, 1, 0)),
        ('work', work(0, query(1))), ('work', work(43, insert)),
        ('work', work(0, query(2) + struct.pack('<q', 2**63-1) + b'\1' + struct.pack('<q', -(2**63)))),
        ('work', work(0, query(7) + struct.pack('<q', -(2**63)) + b'\1' + struct.pack('<q', 17))),
        ('work', work(0, query(8) + struct.pack('<q', 2**63-1))),
        ('outcome', outcome(0, 1, 5, 0, 0, 0)), ('outcome', outcome(1, 9, 13, 2**64-1, 2**64-1, 0)),
        ('outcome', outcome(2, 9, 13, 0, 0, 1)), ('outcome', outcome(3, 9, 13, 0, 0, 0))]
    invalid = [
        ('queue', meta(0, 1, 0)), ('queue', meta(2, 1, 0)), ('queue', meta(2**64-1, 1, 1)),
        ('queue', meta(1, 2**53, 0)), ('queue', meta(0, 0, 2)),
        ('work', work(0, query(3))), ('work', work(0, query(5))), ('work', work(2**53, query(1))),
        ('outcome', outcome(4, 1, 5, 0, 0, 0)), ('outcome', outcome(1, 0, 5, 1, 1, 0)),
        ('outcome', outcome(1, 5, 4, 1, 1, 0)), ('outcome', outcome(1, 1, 5, 1, 2, 0)),
        ('outcome', outcome(0, 1, 5, 1, 1, 0)), ('outcome', outcome(1, 1, 5, 1, 1, 1)),
        ('outcome', outcome(2, 1, 5, 0, 0, 0)), ('outcome', outcome(2, 1, 5, 0, 0, 8))]
    for kind, value in valid:
        invalid.extend([(kind, value[:-1]), (kind, value+b'\0'), (kind, value[:3]+b'\2'+value[4:])])
    return {'version': 1, 'owner': 'examples/station-sdk/TABLES.md',
            'valid': [dict(codec=k, hex=b.hex()) for k, b in valid],
            'invalid': [dict(codec=k, hex=b.hex()) for k, b in invalid]}


def codecs():
    from transit_sdk_examples import table_work as w, codecs as messages
    value = fixtures()
    assert json.loads((ROOT/'tests/sdk/sdk-table-work-v1.json').read_text()) == value
    for case in value['valid']:
        codec = getattr(w, case['codec'] + '_codec'); data = bytes.fromhex(case['hex'])
        assert codec.encode(codec.decode(data)) == data
    for case in value['invalid']:
        try: getattr(w, case['codec'] + '_codec').decode(bytes.fromhex(case['hex']))
        except ValueError: pass
        else: raise AssertionError(case)
    message_cases = json.loads((ROOT/'tests/sdk/sdk-codecs-v1.json').read_text())
    for case in message_cases['valid']:
        codec = getattr(messages, case['codec']); data = bytes.fromhex(case['hex'])
        decoded = codec.decode(data); assert codec.encode(decoded) == data
        if case['codec'] != 'u64': assert type(decoded).__name__ == case['variant']
    for case in message_cases['invalid']:
        try: getattr(messages, case['codec']).decode(bytes.fromhex(case['hex']))
        except ValueError: pass
        else: raise AssertionError(case)
    return len(value['valid']), len(value['invalid']), len(message_cases['valid']) + len(message_cases['invalid'])


def schedule():
    from transit_client import ProcessRef, ResourceRef
    from transit_client.errors import HandlerError
    from transit_station import Cast, Call, Found, Origin, TableCreation, TableMutation, TableMutationStatus, TableMutationState, TableMutationReference, TableRejection
    from transit_station import catalog_values as c
    from transit_sdk_examples import codecs as codec, table_work as w
    from transit_sdk_examples.query import TableService, TABLE
    pid = ProcessRef(46, 3); requester = ProcessRef(46, 9)
    state = {}; domain = {}; mailbox = []; next_input = 0
    terminal = []; attempts = {}; aborted = 0; turns = 0; peak = 0; replies = []; discarded = set()
    class State:
        def __init__(self, turn): self.turn = turn
        def find(self, key): return Found(key.codec.decode(state[key.name])) if key.name in state else None
        def require(self, key):
            found = self.find(key); assert found is not None; return found.value
        def put(self, key, value):
            self.turn.write(); data = key.codec.encode(value); assert len(data) <= 243; state[key.name] = data
        def delete(self, key): self.turn.write(); state.pop(key.name, None)
    class Turn:
        process = pid
        resource = ResourceRef(46, 7)
        def __init__(self, position): self.position = position; self.writes = 0; self.outputs = []; self.state = State(self)
        @property
        def budgets(self): return SimpleNamespace(mutations=4-self.writes)
        def write(self, count=1): self.writes += count; assert self.writes <= 4
        def cast(self, destination, value, *, codec):
            assert destination == pid; self.outputs.append(codec.decode(codec.encode(value)))
        def reply(self, value, *, codec): replies.append(codec.decode(codec.encode(value)))
        def allow_query(self, peer, object_id, *, expected_revision, allow):
            assert peer == requester and object_id == 1 and expected_revision == 0 and allow
            assert 'policy' not in domain; domain['policy'] = True; self.write()
        def create_table(self, schema, limits):
            assert schema == TABLE and len(schema.columns) == 4 and limits.staging_records == 1024
            previous = domain.get('creation')
            if previous is None:
                domain['creation'] = [self.position, 0]; self.write(3); return TableCreation('building', self.position, None)
            if not previous[1]: previous[1] = self.position; self.write(2)
            return TableCreation('applied', previous[0], previous[1])
    def step(intent, turn):
        value = json.loads(intent.save()); operation = int(value['operation']); attempts.setdefault(operation, intent.save()); assert attempts[operation] == intent.save()
        assert value['schema']['object'] == '1' and len(value['schema']['columns']) == 4 and value['principal'] == 0
        reference = TableMutationReference.load(json.dumps(dict(definition=c.DEFINITION, realm=46, resource=7, object='1', principal=0, operation=str(operation), digest='ab'*32), separators=(',', ':')).encode())
        previous = domain.get(operation)
        if previous is None:
            domain[operation] = [turn.position, 0]; turn.write(4)
            return TableMutationStatus(reference, TableMutationState.BUILDING, 'statement', turn.position, None, None, TableRejection.NONE, None)
        if not previous[1]:
            previous[1] = turn.position; terminal.append(operation); turn.write(4)
        rejected = operation == 3
        return TableMutationStatus(reference, TableMutationState.REJECTED if rejected else TableMutationState.APPLIED, 'statement', previous[0], previous[1],
                                   None if rejected else c.Counts(1, 1), TableRejection.ROW_EXISTS if rejected else TableRejection.NONE, None)
    def admit(value, self_output=False, call=False):
        nonlocal next_input
        next_input += 1
        origin = Origin('process', process=pid if self_output else requester) if self_output or call else Origin('external', principal=17)
        mailbox.append(Call(value, next_input, origin, 1) if call else Cast(value, next_input, origin))
        return next_input
    # Insert first requires the recorded initial schema entry. More accepted
    # commands precede the first self continuation, so the live queue cannot
    # assume its head/tail positions are adjacent mailbox inputs.
    identities = [admit(codec.Insert(1, None)), admit(codec.Insert(2, 7)), admit(codec.Insert(2, 8)), admit(codec.Initialize()), admit(codec.Update(1, 17)), admit(codec.Delete(2))]
    admit(codec.Rows(), call=True)
    with patch.object(TableMutation, 'step', step):
        while mailbox:
            assert turns < 100
            incoming = mailbox.pop(0); turn = Turn(incoming.position)
            before = copy.deepcopy((state, domain, terminal, replies)); service = TableService(requester)
            service.handle(turn, incoming); peak = max(peak, turn.writes)
            if turns % 7 == 0 and incoming.position not in discarded:
                # Discard the whole private proposal; retry the same input after
                # replacing every handler object. The scripted domain is rolled
                # back with application state and outputs.
                discarded.add(incoming.position)
                state, domain, terminal, replies = before; mailbox.insert(0, incoming); aborted += 1
            else:
                for value in turn.outputs: admit(value, self_output=True)
            turns += 1
    assert terminal == identities[:3] + identities[4:] and replies == [codec.NotReady()]
    queue = w.queue_codec.decode(state[w.QUEUE.name]); assert queue == w.Queue(0, 0, True)
    assert not any(key.startswith(b'table.work.') for key in state)
    outcomes = [w.outcome_codec.decode(state[w.outcome_key(i).name]) for i in identities]
    assert [v.state for v in outcomes] == [1, 1, 2, 0, 1, 1] and outcomes[2].rejection == 1
    assert w.outcome_key(w.INITIAL).name in state and peak == 4 and aborted >= 2
    denied = False
    try: TableService(requester).handle(Turn(100), Cast(codec.Advance(), 100, Origin('external', principal=17)))
    except HandlerError: denied = True
    assert denied
    return dict(turns=turns, discarded_private_turns=aborted, original_operations=list(attempts), max_writes=peak, outcomes=[asdict(v) for v in outcomes])


if __name__ == '__main__':
    if '--write' in sys.argv:
        (ROOT/'tests/sdk/sdk-table-work-v1.json').write_text(json.dumps(fixtures(), indent=2)+'\n')
    else:
        positive, rejected, message_cases = codecs()
        print(json.dumps(dict(profile='python-sdk-table-work-model', valid=positive, rejected=rejected, application_message_cases=message_cases, schedule=schedule())))
