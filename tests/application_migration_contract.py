"""Independent AM-key/AP1 migration layout and domain commitment fixtures."""
import hashlib
import json
from pathlib import Path
import struct
import sys

PATH = Path(__file__).resolve().parents[1] / 'packages/zig/transit-station-app/src/fixtures/migration-v1.json'

def fixture():
    maximum = (1 << 64) - 1
    proposal = dict(plan=str(maximum), expected=str(maximum - 1), next=str(maximum), transform=2,
                    source=list(range(32)), target=list(range(32, 64)))
    wire = struct.pack('<QQQH', maximum, maximum - 1, maximum, 2) + bytes(range(64))
    digest = hashlib.sha256(b'transit.application.migration.plan.v1\0AP1D' + struct.pack('<Q', 9) + wire).digest()
    plan = dict(proposal=proposal, digest=list(digest), principal=44, input=91)
    step = dict(plan=str(maximum), ordinal=str(maximum - 1), operation=3, arguments='6162')
    step_wire = struct.pack('<QQH', maximum, maximum - 1, 3) + b'\x02ab'
    step_digest = hashlib.sha256(b'transit.application.migration.step.v1\0AP1D' + struct.pack('<Q', 9) + digest + step_wire).digest()
    progress = dict(next=str(maximum), phase='active', cursor='6364', input=92)
    progress_wire = struct.pack('<QB', maximum, 1) + b'\x02cd' + struct.pack('<Q', 92)
    receipt = dict(plan=str(maximum), ordinal=str(maximum - 1), digest=list(step_digest), input=92, progress=progress)
    return dict(version=1, plan=plan, plan_hex=(b'AP1A' + wire + digest + struct.pack('<QQ', 44, 91)).hex(),
                step=step, step_digest=list(step_digest), progress=progress, progress_hex=(b'AP1G' + progress_wire).hex(),
                receipt=receipt, receipt_hex=(b'AP1S' + struct.pack('<QQ', maximum, maximum - 1) + step_digest + struct.pack('<Q', 92) + progress_wire).hex(),
                key_hex=(b'\x00M' + struct.pack('>Q', 9) + b'S' + struct.pack('>QQ', maximum, maximum - 1)).hex())

value = json.dumps(fixture(), indent=2) + '\n'
if '--write' in sys.argv:
    PATH.write_text(value)
else:
    assert PATH.read_text() == value, 'migration fixture drift; run with --write'
    print('Application migration: independent key, record and commitment fixtures passed.')
