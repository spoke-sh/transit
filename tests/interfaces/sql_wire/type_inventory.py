"""Fail closed when SQL aliases or logical types lack an interface disposition."""
import re
from runner.paths import ROOT
from interfaces.sql_wire.type_cases import CASES, UNSUPPORTED_ALIASES, UNSUPPORTED_KINDS


def check(aliases, tags):
    aliases = aliases.split('pub const aliases =',1)[1].split('};',1)[0]
    actual = set(re.findall(r'\.name = "([^"]+)"', aliases))
    expected = {name for case in CASES for name in case.aliases if '(' not in name} | set(UNSUPPORTED_ALIASES)
    assert actual == expected, dict(unclassified=sorted(actual-expected), stale=sorted(expected-actual))
    tags = tags.split('pub const Tag = enum(u8) {',1)[1].split('};',1)[0]
    actual = set(re.findall(r'^\s*(\w+)(?:\s*=\s*\d+)?,', tags, re.M))
    expected = {case.kind for case in CASES} | set(UNSUPPORTED_KINDS)
    assert actual == expected, dict(unclassified=sorted(actual-expected), stale=sorted(expected-actual))
    assert len({case.kind for case in CASES}) == len(CASES)


if __name__ == '__main__':
    aliases = (ROOT/'packages/zig/transit-fuze/src/SqlTypes.zig').read_text()
    tags = (ROOT/'packages/zig/transit-fuze/src/Types.zig').read_text()
    check(aliases, tags)
    for changed_aliases, changed_tags in (
        (aliases.replace('"INT"', '"UNCLASSIFIED_ALIAS"'), tags),
        (aliases, tags.replace('pub const Tag = enum(u8) {', 'pub const Tag = enum(u8) {\n    unclassified_type,')),
        (aliases.replace('"INT"', '"INT64"'), tags),
    ):
        try:
            check(changed_aliases, changed_tags)
        except AssertionError:
            pass
        else:
            raise AssertionError('Missing type disposition did not fail the inventory')
    print('SQL type inventory: every alias/family classified; missing/new type controls rejected.')
