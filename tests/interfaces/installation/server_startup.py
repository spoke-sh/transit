"""Automatic local initialization refuses ambiguous data before starting services."""
import json
from pathlib import Path
import shutil
import subprocess


def admission(fixture):
    original = dict(fixture.config)
    fixture.config['startup'] = {'require_existing': True}
    fixture.path.write_text(json.dumps(fixture.config))
    fixture.refusal('startup requires an existing installation')
    assert not fixture.installation.exists()
    assert not list(fixture.root.glob('installation.creating-*'))
    fixture.installation.mkdir()
    inode = fixture.installation.stat().st_ino
    fixture.refusal('startup requires an existing installation')
    assert fixture.installation.stat().st_ino == inode and not list(fixture.installation.iterdir())
    fixture.installation.rmdir()
    fixture.config = original
    fixture.path.write_text(json.dumps(original))

    # The conventional environment override selects the same admission rule.
    result = subprocess.run([fixture.cli, 'server', '--config', str(fixture.path), '--no-ui'],
                            env={'PATH': '/unavailable', 'TRANSIT_STARTUP__REQUIRE_EXISTING': 'true'},
                            capture_output=True, text=True, timeout=30)
    assert result.returncode == 1 and 'startup requires an existing installation' in result.stderr, result
    assert not fixture.installation.exists()

    for content in (None, 'private-invalid-json', '{}'):
        fixture.installation.mkdir()
        marker = fixture.installation / ('unrecognized' if content is None else 'installation.json')
        marker.write_text(content or 'preserve-data')
        before = marker.read_bytes()
        fixture.refusal('cannot read the retained installation record')
        assert marker.read_bytes() == before and list(fixture.installation.iterdir()) == [marker]
        marker.unlink()
        fixture.installation.rmdir()

    fixture.installation.write_text('preserve-file')
    fixture.refusal('the installation path must be a directory')
    assert fixture.installation.read_text() == 'preserve-file'
    fixture.installation.unlink()
    target = fixture.root / 'symlink-target'
    for exists in (False, True):
        if exists:
            target.mkdir()
        fixture.installation.symlink_to(target, target_is_directory=True)
        fixture.refusal('the installation path must be a directory')
        assert fixture.installation.is_symlink() and target.exists() == exists
        if exists:
            assert not list(target.iterdir())
        fixture.installation.unlink()
    target.rmdir()
    assert not list(fixture.root.glob('installation.creating-*'))
    print('Startup admission: existing-only YAML/environment, missing/empty directories, unknown contents, malformed records, files and symlinks preserved.', flush=True)


def empty_installation(cli, node, host):
    from interfaces.installation.server import Fixture
    fixture = Fixture(cli, node, host)
    success = False
    try:
        fixture.installation.mkdir()
        fixture.start(); fixture.ready(); fixture.stop()
        assert 'creating installation' in Path(fixture.logs[-1].name).read_text()
        before = fixture.record()
        fixture.config['startup'] = {'require_existing': True}
        fixture.path.write_text(json.dumps(fixture.config))
        fixture.start(); fixture.ready(); fixture.stop()
        assert 'opening installation' in Path(fixture.logs[-1].name).read_text()
        after = fixture.record()
        for field in ('installation', 'root_public', 'provision', 'authorization_steps'):
            assert before[field] == after[field], field
        success = True
        print('Startup: empty-directory creation and existing-only restart preserve installation, keys and grants.', flush=True)
    finally:
        fixture.cleanup()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print(f'Failed startup evidence retained at {fixture.root}', flush=True)
