"""Independent negative controls for complete scenario and latency evidence."""
import copy
import unittest

from performance.load.scenario_report import check_budgets, compare, summarize


def campaign():
    manifest = dict(phase='manifest', scenario='console', repeat=2, source={'head': 'a' * 40},
        cli_version='Transit fixture', binaries={'cli': 'b' * 64}, drivers={'driver': 'c' * 64},
        host_id='d' * 64, storage_device=1, host_limits={'affinity': [0]}, toolchain='zig',
        durability='sync', maintenance='enabled', build_mode='ReleaseSafe', cache='retained', unavailable=['copies'])
    records = [dict(phase='campaign', outcome='started'), manifest]
    # Independent inventory; do not obtain the expected cases from production.
    cases = dict(startup=1, retained_restart=1, console_after_restart=1, console_cold=1,
        console_warm_empty=2, console_insert=2, console_after_insert=2, console_warm_one=2,
        console_update=2, console_after_update=2, console_noop=2, console_delete=2,
        console_after_delete=2, console_zero_match=2)
    for case, count in cases.items():
        for index in range(count):
            record = dict(phase='sample', case=case, index=index, outcome='complete', verified=True,
                          elapsed_ns=(index + 1) * 1_000_000)
            if case == 'startup':
                record['definition'] = 'e' * 64
            records.append(record)
    return records + [dict(phase='campaign', outcome='complete')]


class ScenarioReportTest(unittest.TestCase):
    def test_webhook_requires_the_unknown_and_retained_replay_schedules(self):
        records = campaign()[:2]
        records[1].update(scenario='webhook', repeat=1)
        cases = dict(startup=1, retained_restart=1, console_after_restart=1,
            webhook_initial=1, webhook_denied=1, webhook_accept=2, webhook_duplicate=2,
            webhook_derived=2, webhook_refreshed=1, effect_prepare=2, effect_observed=1,
            effect_unknown=1, console_during_http=2, recorded_outcomes=2,
            effect_replay_after_restart=2, outcomes_after_restart=1,
            webhook_to_observed_outcome=1, webhook_to_unknown_outcome=1, derived_result=4, setup=1)
        for case, count in cases.items():
            for index in range(count):
                record = dict(phase='sample', case=case, index=index, outcome='complete', verified=True, elapsed_ns=1000)
                if case == 'startup':
                    record['definition'] = 'e' * 64
                if case in ('effect_observed', 'effect_unknown'):
                    record.update(outcome_phase='observed' if case == 'effect_observed' else 'closed_unknown', sends=1)
                records.append(record)
        records.append(dict(phase='campaign', outcome='complete'))
        summarize(records)
        for case in ('webhook_duplicate', 'effect_unknown', 'effect_replay_after_restart', 'webhook_refreshed'):
            with self.assertRaisesRegex(ValueError, 'missing scenario coverage'):
                summarize([record for record in records if record.get('case') != case])
        changed = copy.deepcopy(records)
        next(record for record in changed if record.get('case') == 'effect_unknown')['outcome_phase'] = 'observed'
        with self.assertRaisesRegex(ValueError, 'effect outcome evidence'):
            summarize(changed)

    def test_complete_results_have_measured_not_invented_tails(self):
        report = summarize(campaign())
        observed = report['distributions']['console_insert']
        self.assertEqual(observed['p50_ms'], 1)
        self.assertEqual(observed['max_ms'], 2)
        self.assertIsNone(observed['p95_ms'])

    def test_incomplete_failed_duplicate_and_unverified_work_cannot_pass(self):
        original = campaign()
        for mutate in (
            lambda rows: rows.pop(),
            lambda rows: rows.pop(5),
            lambda rows: rows.insert(3, copy.deepcopy(rows[3])),
            lambda rows: rows[5].update(outcome='failed'),
            lambda rows: rows[5].update(verified=False),
            lambda rows: rows[5].update(elapsed_ns=-1),
            lambda rows: rows[5].update(elapsed_ns=True),
            lambda rows: rows[5].update(index=100),
            lambda rows: rows[2].pop('definition'),
            lambda rows: rows[1].update(scenario='all'),
        ):
            with self.subTest(mutate=mutate):
                altered = copy.deepcopy(original)
                mutate(altered)
                with self.assertRaises(ValueError):
                    summarize(altered)

    def test_late_success_and_insufficient_tail_samples_fail_the_gate(self):
        report = summarize(campaign())
        budgets = dict(scenario='console', minimum_repeat=2, limits_ms={'console_insert': {'max_ms': 2}})
        check_budgets(report, budgets)
        for limits in ({'max_ms': 1.9}, {'p95_ms': 1000}, {'p50_ms': float('nan')}, {'samples': 1000}):
            with self.assertRaises(ValueError):
                check_budgets(report, dict(budgets, limits_ms={'console_insert': limits}))
        for changes in (dict(scenario='all'), dict(minimum_repeat=3), dict(minimum_repeat=True), dict(limits_ms={})):
            with self.assertRaises(ValueError):
                check_budgets(report, dict(budgets, **changes))
        records = campaign()
        records[1]['budgets'] = dict(budgets, limits_ms={'console_insert': {'max_ms': 1.9}})
        with self.assertRaisesRegex(ValueError, 'budget exceeded'):
            summarize(records)

    def test_comparison_preserves_definition_driver_and_durability(self):
        control = summarize(campaign())
        self.assertEqual(compare(control, copy.deepcopy(control), 1.25)['console_insert'], 1)
        for field in ('definition', 'drivers', 'host_id', 'host_limits', 'durability', 'maintenance', 'repeat'):
            candidate = copy.deepcopy(control)
            candidate['manifest'][field] = 'different'
            with self.assertRaisesRegex(ValueError, 'incomparable'):
                compare(control, candidate, 1.25)
        candidate = copy.deepcopy(control)
        candidate['distributions']['console_insert']['p50_ms'] *= 2
        with self.assertRaisesRegex(ValueError, 'regression'):
            compare(control, candidate, 1.25)


if __name__ == '__main__':
    unittest.main()
