"""Independent manual-handoff record and complete paged-state digest fixtures."""
from runner.paths import ROOT
import argparse
import hashlib
import json
from pathlib import Path
import struct

FIXTURE = ROOT / 'packages/zig/transit-client/src/fixtures/worker-handoff.json'


def fixture():
    definition = json.loads((ROOT / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition']
    plan = dict(id=1, realm=2, pid=3, resource=4, worker=5, generation=7, resume_before_ms=10000,
                expected_public_key=[11] * 32, public_key=[12] * 32, permissions=88,
                application=[13] * 32, old_instance=[14] * 32, new_instance=[15] * 32)
    state = dict(resource=4, writer=3, revision=20, entries=19, bytes=1900, digest=[16] * 32)
    record = dict(definition=definition, plan=plan, phase='checkpointed',
                  checkpoint=dict(state=state, revision=4, consumed=4, cancelled=0, admitted=6), retired_instance=None)
    digest = hashlib.sha256(b'transit.worker-handoff.state.v1\0' + definition.encode()
                            + struct.pack('<4Q', 4, 3, 20, 10003))
    for index in range(10003):
        digest.update(struct.pack('<3Q', index % 20, 8, 5))
        digest.update(struct.pack('>Q', index) + b'value')
    return dict(record=json.dumps(record, separators=(',', ':')), state_digest=digest.hexdigest())


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    encoded = json.dumps(fixture(), indent=2) + '\n'
    if args.write:
        FIXTURE.parent.mkdir(parents=True, exist_ok=True)
        FIXTURE.write_text(encoded)
    elif FIXTURE.read_text() != encoded:
        raise SystemExit('Worker handoff fixtures drifted; review before --write')
    print('Worker handoff: independent canonical record and 10,003-entry digest passed.')
