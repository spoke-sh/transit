"""Retain notices from the exact bundled dependency sources."""
from pathlib import Path
import shutil
import sys
import tarfile

output, dependencies, openssl, musl = map(Path, sys.argv[1:])
output.mkdir(parents=True)
for root, label in ((Path('third_party'), 'third_party'), (dependencies, 'zig-dependencies')):
    for path in sorted(root.rglob('*')):
        if path.is_file() and path.name.upper().startswith(('LICENSE', 'COPYING', 'COPYRIGHT', 'NOTICE')):
            target = output / label / path.relative_to(root)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, target)
for source, suffix, name in ((openssl, '/LICENSE.txt', 'OpenSSL-LICENSE.txt'),
                             (musl, '/COPYRIGHT', 'musl-COPYRIGHT')):
    with tarfile.open(source) as archive:
        member, = [member for member in archive if member.isfile() and member.name.endswith(suffix)]
        with archive.extractfile(member) as stream:
            (output / name).write_bytes(stream.read())
shutil.copyfile('packages/zig/transit-tls/NOTICE', output / 'transit-tls-NOTICE')
