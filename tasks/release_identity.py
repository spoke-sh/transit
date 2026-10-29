#!/usr/bin/env python3
"""One source-bound identity for stable and nightly distribution artifacts."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = ('python', 'node', 'rust', 'ruby', 'c', 'java', 'dotnet', 'beam', 'go', 'zig')
STABLE = r'(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)'
NIGHTLY = rf'({STABLE})-nightly\.([0-9]{{8}})\.g([0-9a-f]{{12}})'


def git(*args, root=ROOT):
    return subprocess.check_output(['git', *args], cwd=root, text=True).strip()


def describe(base, revision, epoch, channel='stable', date=None):
    if not re.fullmatch(STABLE, base) or not re.fullmatch(r'[0-9a-f]{40}', revision):
        raise ValueError('release identity requires a stable base version and full source SHA')
    if type(epoch) is not int or epoch < 0 or channel not in ('stable', 'nightly'):
        raise ValueError('invalid release epoch/channel')
    versions = dict.fromkeys(LANGUAGES, base)
    release, tag = base, f'v{base}'
    if channel == 'nightly':
        if not date or not re.fullmatch(r'[0-9]{8}', date):
            raise ValueError('nightly date must be YYYYMMDD')
        datetime.strptime(date, '%Y%m%d')
        suffix = f'{date}.g{revision[:12]}'
        release, tag = f'{base}-nightly.{suffix}', f'nightly-{date}-g{revision[:12]}'
        versions = dict.fromkeys(LANGUAGES, release)
        versions['python'] = f'{base}.dev{date}+g{revision[:12]}'
        versions['ruby'] = f'{base}.nightly.{suffix}'
        # Zig limits build.zig.zon versions to 32 bytes. The enclosing release
        # identity retains the nightly date and full revision.
        versions['zig'] = f'{base}-dev.g{revision[:12]}'
    elif date is not None:
        raise ValueError('stable releases do not have a nightly date')
    if len(versions['zig']) > 32:
        raise ValueError('Zig package version exceeds 32 bytes')
    return dict(version=1, channel=channel, base_version=base, release=release, tag=tag,
                source_revision=revision, source_date_epoch=epoch, date=date,
                package_versions=versions)


def validate(data):
    expected = describe(data['base_version'], data['source_revision'],
                        data['source_date_epoch'], data['channel'], data['date'])
    if data != expected:
        raise ValueError('release identity fields disagree')
    return data


def current(root=ROOT, *, clean=False):
    base = (root / 'VERSION').read_text().strip()
    revision = git('rev-parse', 'HEAD', root=root)
    epoch = int(git('show', '-s', '--format=%ct', 'HEAD', root=root))
    path = os.environ.get('TRANSIT_RELEASE_IDENTITY')
    result = validate(json.loads(Path(path).read_text())) if path else describe(base, revision, epoch)
    if (result['base_version'], result['source_revision'], result['source_date_epoch']) != (base, revision, epoch):
        raise ValueError('release identity does not identify this checkout')
    if clean and git('status', '--porcelain', root=root):
        raise ValueError('release distribution requires a clean source checkout')
    return result


def tag_for(version):
    if re.fullmatch(STABLE, version):
        return f'v{version}'
    match = re.fullmatch(NIGHTLY, version)
    if match:
        datetime.strptime(match[2], '%Y%m%d')
        return f'nightly-{match[2]}-g{match[3]}'
    raise ValueError('invalid Transit release version')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    show = sub.add_parser('show')
    show.add_argument('--field')
    create = sub.add_parser('create')
    create.add_argument('--channel', choices=('stable', 'nightly'), required=True)
    create.add_argument('--date', help='UTC date of the original workflow run; YYYYMMDD')
    create.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.command == 'create':
        data = current(clean=True)
        date = args.date
        if args.channel == 'nightly' and date is None:
            date = datetime.now(timezone.utc).strftime('%Y%m%d')
        data = describe(data['base_version'], data['source_revision'], data['source_date_epoch'], args.channel, date)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(data, indent=2) + '\n')
    else:
        data = current()
    print(data[args.field] if args.command == 'show' and args.field else json.dumps(data))
