"""Independent controls for installed log benchmark evidence and denominators."""
import copy
import hashlib
import unittest

from performance.storage import log_runtime as driver


def sample():
    counts = dict(alloc_attempts=1, alloc_successes=1, resize_attempts=0, resize_successes=0,
                  growing_resize_attempts=0, remap_attempts=0, remap_successes=0,
                  frees=1, requested_bytes=512, acquired_bytes=512, released_bytes=512,
                  forbidden_attempts=0)
    # Independently written row-zero bytes: one LE-u64 plus a known 128-byte
    # modular progression, rather than the production encoder or report oracle.
    payload = bytes.fromhex('0726456483a2c1e0ff1e3d5c7b9ab9d8f71635547392b1d0ef0e2d4c6b8aa9c8e70625446382a1c0dffe1d3c5b7a99b8d7f61534537291b0cfee0d2c4b6a89a8c7e60524436281a0bfdefd1c3b5a7998b7d6f51433527190afceed0c2b4a6988a7c6e504234261809fbeddfc1b3a597897b6d5f4133251708faecdec0b2a4968')
    records = [dict(event='attempt', profile=1, serial=1, stage='measured', action='append'),
               dict(event='sample', profile=1, serial=1, stage='measured', action='append', http_calls=1, ns=17, backing=counts),
               dict(event='readback', profile=1, stage='measured', offsets=[0], sha256=hashlib.sha256(bytes(8) + payload).hexdigest()),
               dict(event='owner_budgets', profile=1, limits=dict(
                   catalog_pages=16, catalog_index_work_bytes=64 * 1024 * 1024,
                   partition_pages=16, partition_index_work_bytes=8 * 1024 * 1024,
                   tail_slots=2, tail_borrow_slots=16, tail_slot_bytes=1024 * 1024,
                   tail_resident_bytes=3 * 1024 * 1024,
                   queue_candidate_objects=None, queue_candidate_resident_bytes=None,
                   queue_deadline_rows=None, queue_visibility_rows=None, queue_affinity_rows=None)),
               dict(event='complete', profile=1, recovery=False, build_mode='safe')]
    profile = dict(driver.PROFILES[0], warmup=0, repeat=1)
    return records, profile


class Reports(unittest.TestCase):
    def test_complete_independently_encoded_sample(self):
        records, profile = sample()
        result = driver.validate(records, profile, False)
        self.assertEqual(1, result['successful'])
        self.assertEqual(17, result['distributions']['append']['p50_ns'])

    def test_missing_terminal_attempt_and_mismatched_bytes_fail(self):
        records, profile = sample()
        variants = [records[:-1], records[1:], records[:1] + records[2:]]
        corrupt = copy.deepcopy(records)
        corrupt[2]['sha256'] = '0' * 64
        variants.append(corrupt)
        for variant in variants:
            with self.assertRaises(ValueError):
                driver.validate(variant, profile, False)

    def test_digest_cannot_hide_missing_or_duplicate_rows(self):
        records, profile = sample()
        for offsets in ([], [0, 0], [1]):
            changed = copy.deepcopy(records)
            changed[2].update(offsets=offsets, sha256=driver.oracle(offsets))
            with self.assertRaises(ValueError):
                driver.validate(changed, profile, False)

    def test_recovery_and_build_identity_are_mandatory(self):
        records, profile = sample()
        with self.assertRaises(ValueError):
            driver.validate(records, profile, True)
        records[-1]['build_mode'] = 'debug'
        with self.assertRaises(ValueError):
            driver.validate(records, profile, False)

    def test_missing_and_impossible_allocation_counters_fail(self):
        records, profile = sample()
        for change in ('missing', 'successes', 'growth'):
            changed = copy.deepcopy(records)
            counts = changed[1]['backing']
            if change == 'missing':
                del counts['requested_bytes']
            elif change == 'successes':
                counts['alloc_successes'] = counts['alloc_attempts'] + 1
            else:
                counts['growing_resize_attempts'] = counts['resize_attempts'] + 1
            with self.assertRaises(ValueError):
                driver.validate(changed, profile, False)

    def test_recovery_progress_is_counted_and_cannot_replay_mutations(self):
        records, profile = sample()
        progress = dict(event='recovery_step', profile=1, serial=1, http_call=1)
        records.insert(1, progress)
        records[2]['http_calls'] = 2
        with self.assertRaises(ValueError):
            driver.validate(records, profile, False)
        records[0]['action'] = records[2]['action'] = 'operation'
        records[-1]['recovery'] = True
        records[3]['stage'] = 'recovery'
        result = driver.validate(records, profile, True)
        self.assertEqual(2, result['http_calls'])
        self.assertEqual(1, result['recovery_steps'])
        records[2]['http_calls'] = 3
        with self.assertRaises(ValueError):
            driver.validate(records, profile, True)

    def test_percentiles_require_enough_successful_samples(self):
        self.assertIsNone(driver.distribution(list(range(1, 20)))['p95_ns'])
        self.assertEqual(19, driver.distribution(list(range(1, 21)))['p95_ns'])
        self.assertIsNone(driver.distribution(list(range(1, 100)))['p99_ns'])
        self.assertEqual(99, driver.distribution(list(range(1, 101)))['p99_ns'])

    def test_final_response_must_meet_deadline_even_after_recovery(self):
        records, profile = sample()
        records[0]['action'] = records[1]['action'] = 'operation'
        records[-1]['recovery'] = True
        records[2]['stage'] = 'recovery'
        records.insert(1, dict(event='recovery_step', profile=1, serial=1, http_call=1))
        records[2]['http_calls'] = 2
        records[2]['ns'] = 29_999_999_999
        self.assertTrue(driver.validate(records, profile, True)['passed'])
        for ns in (30_000_000_000, 30_000_000_001):
            records[2]['ns'] = ns
            with self.assertRaises(ValueError):
                driver.validate(records, profile, True)
            self.assertEqual(dict(passed=False, attempts=1, successful=0, refused=0, failed=1, unknown=0), driver.incomplete(records))

    def test_late_known_mutation_is_failed_measurement_not_unknown_work(self):
        records = [dict(event='attempt', serial=1),
                   dict(event='failure', serial=1, cause='CallBudget', mutation_attempted=True,
                        known_outcome=True, ns=30_000_000_001)]
        self.assertEqual(dict(passed=False, attempts=1, successful=0, refused=0, failed=1, unknown=0), driver.incomplete(records))
        records[1]['known_outcome'] = False
        self.assertEqual(1, driver.incomplete(records)['unknown'])

    def test_owner_budgets_cannot_be_missing_duplicated_or_attributed_to_another_owner(self):
        records, profile = sample()
        for variant in (records[:3] + records[4:], records[:4] + records[3:]):
            with self.assertRaises(ValueError):
                driver.validate(variant, profile, False)
        for key, value in (('catalog_index_work_bytes', 0), ('tail_slots', True), ('queue_candidate_objects', 4)):
            changed = copy.deepcopy(records)
            changed[3]['limits'][key] = value
            with self.assertRaises(ValueError):
                driver.validate(changed, profile, False)
        records[3]['limits']['catalog_pages'] = records[3]['limits']['partition_pages'] = 0
        self.assertEqual(0, driver.validate(records, profile, False)['owner_budgets']['catalog_pages'])

    def test_unknown_is_not_rejection_or_omitted(self):
        records = [dict(event='attempt', serial=i) for i in range(5)]
        records += [dict(event='sample', serial=0, ns=17),
                    dict(event='failure', serial=1, diagnostic=dict(outcome='rejected')),
                    dict(event='failure', serial=2, diagnostic=dict(outcome='unknown')),
                    dict(event='failure', serial=3, mutation_attempted=False)]
        result = driver.incomplete(records)
        self.assertEqual(dict(passed=False, attempts=5, successful=1, refused=1, failed=1, unknown=2), result)


if __name__ == '__main__':
    unittest.main()
