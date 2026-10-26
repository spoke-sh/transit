"""Actual offline generator and compiled helpers, independent descriptor mutations."""
from runner.paths import ROOT
from pathlib import Path
import subprocess
import sys
import tempfile
from google.protobuf import descriptor_pb2

generator, consumer = sys.argv[1:]
fixture = ROOT / 'tests/fixtures/grpc/peer.pb'
output = subprocess.check_output([generator, str(fixture)], timeout=10)
formatted = subprocess.check_output(['zig', 'fmt', '--stdin'], input=output, timeout=10)
assert formatted == fixture.with_name('methods.zig').read_bytes(), 'Generated RPC helper drift'
subprocess.run([consumer], check=True, timeout=10)
with tempfile.TemporaryDirectory(prefix='transit-grpc-codegen-') as directory:
    target = Path(directory) / 'invalid.pb'
    data = descriptor_pb2.FileDescriptorSet.FromString(fixture.read_bytes())
    data.file[0].service[0].method[-1].input_type = '.missing.Input'
    for contents in (b'', fixture.read_bytes()[:-1], data.SerializeToString(), bytes(65537)):
        target.write_bytes(contents)
        result = subprocess.run([generator, str(target)], capture_output=True, timeout=10)
        assert result.returncode != 0 and result.stdout == b'', 'Invalid descriptor emitted helper source'
print('Offline RPC helpers: reproducible source, compiled four-shape requests, pinned digest and invalid descriptor refusal passed.')
