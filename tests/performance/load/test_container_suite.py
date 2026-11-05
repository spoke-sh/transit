"""Nightly image provenance, independent values and incomplete-campaign controls."""
import copy
import hashlib
import json
import re
import runpy
import sys
import unittest
from unittest.mock import patch

from performance.load.container_suite import CASES, advance_oracle, command, inventory, plan, rows, summarize, verify_image
from runner.paths import ROOT

sys.path.insert(0, str(ROOT / 'tasks'))
try:
    resolver = runpy.run_path(str(ROOT / 'tasks/performance_image.py'))
    describe = runpy.run_path(str(ROOT / 'tasks/release_identity.py'))['describe']
finally:
    sys.path.pop(0)


def release():
    identity = describe('0.0.1', 'a' * 40, 123, 'nightly', '20261104')
    manifest = dict(identity=identity, source_revision=identity['source_revision'], release=identity['release'], definition='b' * 64,
                    images={'transit': dict(digest='sha256:' + 'c' * 64, platforms={
                        name: dict(config='sha256:' + 'd' * 64, manifest='sha256:' + 'e' * 64)
                        for name in ('linux/amd64', 'linux/arm64')})})
    content = json.dumps(manifest).encode()
    digest = hashlib.sha256(content).hexdigest()
    checksums = (digest + '  release-manifest.json\n').encode()
    descriptor = dict(version=1, identity=identity, manifest_sha256=digest,
                      checksums_sha256=hashlib.sha256(checksums).hexdigest(), workflow_run=123)
    return descriptor, content, checksums


def selected():
    return resolver['selection']('spoke-sh/transit', *release(), channel_commit='f' * 40)


def campaign(nodes=1):
    clients, repeat, warmup = 3, 2, 2
    data = [dict(phase='campaign', outcome='started'), dict(phase='manifest', selected=selected(),
                nodes=nodes, clients=clients, rows=8, repeat=repeat, warmup=warmup)]
    data += [dict(phase='sample', case=case, worker=worker, index=index, outcome='complete', verified=True, elapsed_ns=100)
             for case, worker, index in sorted(inventory(clients, repeat, warmup))]
    data += [dict(phase='stage', case=case, outcome='complete') for case in ('setup', 'verify', 'cleanup')]
    data += [dict(phase='stage', case=f'{case}_{node}', outcome='complete') for node in range(nodes)
             for case in ('startup', 'restart', 'restart_verify')]
    data += [dict(phase='window', case=case, elapsed_ns=1000) for case in CASES]
    data += [dict(phase='resources', case=case, containers=[{} for _ in range(nodes)]) for case in ('setup', *CASES)]
    data += [dict(phase='client', ordinal=ordinal, exit_code=0) for ordinal in range(clients + 2 * nodes)]
    return data + [dict(phase='campaign', outcome='complete')]


def result(expected):
    def cell(value):
        return dict(value=dict(atom=dict(signed=str(value))))
    return dict(schema=dict(type=dict(structure=[dict(name='id'), dict(name='value')])),
                rows=[[cell(key), cell(value)] for key, value in expected.items()], complete=dict(rows=str(len(expected))))


class NightlyContainers(unittest.TestCase):
    def test_channel_requires_exact_manifest_checksums_and_source(self):
        descriptor, manifest, checksums = release()
        value = selected()
        self.assertEqual(value['image'], 'ghcr.io/spoke-sh/transit@sha256:' + 'c' * 64)
        mutations = (
            (None, manifest, checksums),
            (descriptor, manifest + b' ', checksums),
            (descriptor, manifest, checksums + checksums),
            ({**descriptor, 'manifest_sha256': '0' * 64}, manifest, checksums),
            ({**descriptor, 'checksums_sha256': '0' * 64}, manifest, checksums),
            ({**descriptor, 'identity': {}}, manifest, checksums),
        )
        for changed in mutations:
            with self.subTest(changed=changed[0]), self.assertRaises(ValueError):
                resolver['selection']('spoke-sh/transit', *changed, channel_commit='f' * 40)

    def test_absent_channel_does_not_select_an_unqualified_release(self):
        with patch.dict(resolver['resolve'].__globals__, channel=lambda _: (None, None)):
            with self.assertRaisesRegex(ValueError, 'no promoted nightly'):
                resolver['resolve']('spoke-sh/transit')

    def test_manual_candidate_remains_distinct_from_promotion(self):
        descriptor, manifest, checksums = release()
        value = resolver['selection']('spoke-sh/transit', None, manifest, checksums, candidate_tag=descriptor['identity']['tag'])
        self.assertEqual(value['selection'], 'explicit-unpromoted-candidate')
        self.assertIsNone(value['publication_run'])
        with self.assertRaises(ValueError):
            resolver['selection']('spoke-sh/transit', None, manifest, checksums, candidate_tag='nightly-20261104-g000000000000')

    def test_image_platform_config_and_labels_must_match(self):
        value = selected()
        image = dict(Id='sha256:' + 'd' * 64, Os='linux', Architecture='amd64', Config=dict(Labels={
            'org.opencontainers.image.revision': value['identity']['source_revision'],
            'org.opencontainers.image.version': value['identity']['release']}))
        verify_image(value, image, 'linux/amd64')
        for field, changed in (('Id', 'sha256:' + '0' * 64), ('Architecture', 'arm64')):
            with self.assertRaises(ValueError):
                verify_image(value, {**image, field: changed}, 'linux/amd64')
        image['Config']['Labels']['org.opencontainers.image.revision'] = '0' * 40
        with self.assertRaises(ValueError):
            verify_image(value, image, 'linux/amd64')

    def test_values_counts_and_terminal_coverage_are_independent(self):
        expected = {1: 10, 2: 20}
        rows(result(expected), expected)
        for wrong in ({1: 10}, {1: 11, 2: 20}, {1: 10, 3: 20}):
            with self.assertRaises(ValueError):
                rows(result(wrong), expected)
        value = result(expected)
        value['complete']['rows'] = '99'
        with self.assertRaises(ValueError):
            rows(value, expected)
        complete = dict(completion=dict(outcome='applied', counts=dict(matched='1', changed='1')))
        command(complete, 1)
        for outcome in ('rejected', 'cancelled', 'partial', None):
            with self.assertRaises(ValueError):
                command(dict(completion=dict(outcome=outcome)), 1)
        with self.assertRaises(ValueError):
            command(complete, 0)

    def test_missing_failed_duplicate_samples_and_lifecycles_reject(self):
        for nodes in (1, 3):
            data = campaign(nodes)
            self.assertEqual(summarize(data)['cases']['point_hot']['samples'], 6)
            for phase in ('sample', 'window', 'stage', 'resources', 'manifest', 'campaign', 'client'):
                index = next(i for i, row in enumerate(data) if row['phase'] == phase)
                with self.subTest(nodes=nodes, phase=phase), self.assertRaises(ValueError):
                    summarize(data[:index] + data[index+1:])
                with self.subTest(nodes=nodes, duplicate=phase), self.assertRaises(ValueError):
                    summarize(data[:index] + [data[index]] + data[index:])
            for field, value in (('verified', False), ('outcome', 'failed'), ('elapsed_ns', 0), ('worker', 99)):
                changed = copy.deepcopy(data)
                changed[2][field] = value
                with self.assertRaises(ValueError):
                    summarize(changed)
            with self.assertRaises(ValueError):
                summarize(data[:-1] + [dict(phase='failure'), data[-1]])
            for stage in ('cleanup', f'restart_verify_{nodes-1}'):
                changed = copy.deepcopy(data)
                next(row for row in changed if row.get('case') == stage)['outcome'] = 'failed'
                with self.assertRaises(ValueError):
                    summarize(changed)

    def test_mixed_oracle_uses_declared_writes(self):
        expected = {'hot': {0: 0}, 'partition_0': {0: 0}}
        for index in range(-2, 4):
            sql, verify = plan('mixed', 0, index, expected)
            if index % 2:
                self.assertIn('SELECT', sql)
                verify(result({0: 100000 + index - 1}))
            else:
                self.assertIn('UPDATE', sql)
                verify(dict(completion=dict(outcome='applied', counts=dict(matched='1', changed='1'))))
        advance_oracle('mixed', 0, 3, expected)
        self.assertEqual(expected['hot'], {0: 100002})

    def test_schedule_is_twelve_hours_after_release(self):
        def schedule(name):
            value = (ROOT / '.github/workflows' / name).read_text()
            minute, hour = map(int, re.search(r"cron: '(\d+) (\d+) \* \* \*'", value).groups())
            return hour * 60 + minute
        self.assertEqual((schedule('nightly-performance.yml') - schedule('nightly.yml')) % 1440, 720)


if __name__ == '__main__':
    unittest.main()
