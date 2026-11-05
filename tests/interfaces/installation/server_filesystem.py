#!/usr/bin/env python3
"""Real embedded runtime with named temporaries and no RENAME_NOREPLACE.

The seccomp profile reproduces syscall limitations, not NFS durability or locks.
--native-filesystem instead exercises a caller-selected disposable mounted parent.
"""
import argparse
import ctypes
import errno
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tempfile


def restrict_filesystem():
    """Inherited kernel filter: reject only the two unsupported operations."""
    machines = {'x86_64': (0xc000003e, 257, 316), 'aarch64': (0xc00000b7, 56, 276)}
    arch, openat, renameat2 = machines[platform.machine()]
    # sock_filter: code, jt, jf, k. seccomp_data: nr@0, arch@4, args@16.
    instructions = [
        (0x20, 0, 0, 4), (0x15, 1, 0, arch), (0x06, 0, 0, 0x80000000),
        (0x20, 0, 0, 0), (0x15, 0, 3, renameat2),
        (0x20, 0, 0, 16 + 8 * 4), (0x45, 0, 5, 1),
        (0x06, 0, 0, 0x00050000 | errno.EINVAL),
        (0x15, 0, 3, openat), (0x20, 0, 0, 16 + 8 * 2),
        # __O_TMPFILE; O_TMPFILE also includes O_DIRECTORY.
        (0x45, 0, 1, os.O_TMPFILE & ~os.O_DIRECTORY),
        (0x06, 0, 0, 0x00050000 | errno.EOPNOTSUPP),
        (0x06, 0, 0, 0x7fff0000),
    ]
    class Filter(ctypes.Structure):
        _fields_ = [('code', ctypes.c_ushort), ('jt', ctypes.c_ubyte), ('jf', ctypes.c_ubyte), ('k', ctypes.c_uint)]
    class Program(ctypes.Structure):
        _fields_ = [('length', ctypes.c_ushort), ('filter', ctypes.POINTER(Filter))]
    filters = (Filter * len(instructions))(*(Filter(*item) for item in instructions))
    program = Program(len(filters), filters)
    libc = ctypes.CDLL(None, use_errno=True)
    for option, argument in ((38, 1), (22, 2)):
        result = libc.prctl(option, argument, ctypes.byref(program) if option == 22 else 0, 0, 0)
        if result != 0:
            raise OSError(ctypes.get_errno(), 'seccomp profile installation failed')


def controls(parent):
    """Reject an ineffective filter before treating the runtime as qualified."""
    with tempfile.TemporaryDirectory(prefix='filesystem-controls-', dir=parent) as directory:
        root = Path(directory)
        source, target = root / 'source', root / 'target'
        source.write_bytes(b'original')
        target.mkdir()
        libc = ctypes.CDLL(None, use_errno=True)
        assert libc.renameat2(-100, os.fsencode(source), -100, os.fsencode(target), 1) == -1
        assert ctypes.get_errno() == errno.EINVAL
        assert source.read_bytes() == b'original' and target.is_dir()
        try:
            fd = os.open(directory, os.O_TMPFILE | os.O_RDWR, 0o600)
        except OSError as error:
            assert error.errno == errno.EOPNOTSUPP, error
        else:
            os.close(fd)
            raise AssertionError('O_TMPFILE was not rejected')
        os.link(source, root / 'linked')
        assert (root / 'linked').read_bytes() == b'original'
        os.rename(source, root / 'renamed')
        try:
            os.link(root / 'renamed', target)
        except FileExistsError:
            pass
        else:
            raise AssertionError('hard link replaced an existing directory')


def run(cli, worker, operator, parent, native_filesystem):
    from interfaces.installation.server_applications import Applications
    from interfaces.cli.table_console import records
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    fixture = Applications(cli, cli, cli, parent=parent)
    fixture.config['executables'] = {}
    fixture.path.write_text(json.dumps(fixture.config))
    binary = fixture.cli
    if not native_filesystem:
        wrapper = fixture.root / 'filtered-transit'
        wrapper.write_text(f'#!{sys.executable}\nimport os\nos.execv({sys.executable!r}, [{sys.executable!r}, {str(Path(__file__).resolve())!r}, "--filtered-exec", {binary!r}] + __import__("sys").argv[1:])\n')
        wrapper.chmod(0o700)
        fixture.cli = str(wrapper)
    success = False
    profile = 'native-filesystem' if native_filesystem else 'restricted-syscalls'
    print(f'Filesystem proof ({profile}): {fixture.root}', flush=True)
    try:
        fixture.start()
        fixture.ready()
        original = fixture.record()
        fixture.refusal('another server manages this installation')
        fixture.console('CREATE TABLE filesystem_rows (id INT, name VARCHAR);')
        fixture.console("INSERT INTO filesystem_rows VALUES (7, 'retained');")
        expected = [{'id': '7', 'name': 'retained'}]
        assert records(fixture.console('SELECT * FROM filesystem_rows;')[-1]) == expected
        declaration = json.loads(subprocess.check_output([str(Path(operator).resolve()), 'manifest', str(Path(worker).resolve())], text=True))
        manifest = fixture.root / 'application.yaml'
        manifest.write_text('\n'.join(f'{key}: {json.dumps(value)}' for key, value in declaration.items()))
        fixture.app('install', '--file', manifest, '--operation', 'install-1')
        first = fixture.active()
        identities = [(role['pid'], role['principal']) for role in first['roles']]
        resources = [resource['id'] for resource in first['resources']]
        publications = sorted(fixture.installation.rglob('.transit-published'))
        assert len(publications) >= 4, publications  # root, SQL, account, application
        frozen = {str(path.relative_to(fixture.installation)): path.read_bytes() for path in publications}
        fixture.stop(kill=True)
        fixture.start()
        fixture.ready()
        recovered = fixture.record()
        for key in ('installation', 'root_public', 'default_table'):
            assert recovered[key] == original[key], key
        assert records(fixture.console('SELECT * FROM filesystem_rows;')[-1]) == expected
        fixture.app('retry', '--operation', 'install-1')
        second = fixture.active()
        assert [(role['pid'], role['principal']) for role in second['roles']] == identities
        assert [resource['id'] for resource in second['resources']] == resources
        assert {str(path.relative_to(fixture.installation)): path.read_bytes() for path in fixture.installation.rglob('.transit-published')} == frozen
        fixture.stop()
        assert not list(fixture.root.rglob('.publishing-*'))
        assert not list(fixture.root.rglob('.creating-*'))
        print(json.dumps(dict(profile=profile, executable_sha256=hashlib.sha256(Path(binary).read_bytes()).hexdigest(), publication_count=len(frozen), retained_rows=1, completed=True)), flush=True)
        success = True
    finally:
        fixture.cleanup()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print(f'Private failure evidence retained at {fixture.root}', file=sys.stderr)


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == '--filtered-exec':
        restrict_filesystem()
        controls(Path(sys.argv[2]).parent)
        os.execv(sys.argv[2], sys.argv[2:])
    else:
        parser = argparse.ArgumentParser(description=__doc__)
        parser.add_argument('cli')
        parser.add_argument('worker')
        parser.add_argument('operator')
        parser.add_argument('--parent', default='/var/tmp', help='Existing writable disposable parent; never an existing installation')
        parser.add_argument('--native-filesystem', action='store_true', help='Exercise the selected filesystem without syscall injection')
        run(**vars(parser.parse_args()))
