#!/usr/bin/env python3
"""Downstream consumer of the Nix manifest; runtime has an unavailable PATH."""
import ctypes
import json
from pathlib import Path
import shutil
import sys

import server
from server_board import Board


def run(package):
    package = Path(package).resolve()
    executables = json.loads((package / 'share/transit/local-executables.json').read_text())
    assert set(executables) == {'minio', 'ursula', 'node', 'query_host', 'board'}
    assert all(Path(path).is_file() for path in executables.values())
    # Select the packaged provider before constructing the shared fixture:
    # the source proof's Docker-based MinIO extraction is never invoked here.
    server.minio_binary = lambda: Path(executables['minio'])
    fixture = Board(package / 'bin/transit', executables['node'], executables['query_host'], executables['board'])
    fixture.config['executables'] = executables
    fixture.path.write_text(json.dumps(fixture.config))
    success = False
    try:
        fixture.alias = 'serve'
        fixture.start(initialize=True)
        report = fixture.ready()
        assert report['board_url'] == fixture.board_url
        assert b'<script' in fixture.get('/')
        assert len([entry for entry in fixture.atlas()['resources']['entries'] if entry]) == 2
        record = fixture.record()
        fixture.stop()
        fixture.no_ui = True
        fixture.start()
        fixture.ready()
        fixture.stop()
        fixture.no_ui = False
        fixture.start()
        fixture.ready()
        assert fixture.record()['installation'] == record['installation']
        assert fixture.record()['board_receipts'] == record['board_receipts']
        success = True
        print('Packaged downstream manifest: default embedded Board, --no-ui, re-enable and retained identity passed without runtime PATH tools.', flush=True)
    finally:
        fixture.cleanup()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print(f'Packaged failure evidence retained: {fixture.root}', file=sys.stderr)


if __name__ == '__main__':
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    run(sys.argv[1])
