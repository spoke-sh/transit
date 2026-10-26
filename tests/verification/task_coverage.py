"""Check declared task ownership against the pinned Just recipe inventory.

Recipe nesting accepts dependencies and literal standalone Just commands only.
It is a scheduling check, not a shell interpreter or evidence of test execution.
Indirect nesting through Zig/Python remains an explicitly reviewed declaration.
"""
from collections import Counter
import json
import subprocess


def read_recipes(root):
    result = subprocess.run(
        ["just", "--dump", "--dump-format", "json"], cwd=root,
        check=True, capture_output=True, text=True,
    )
    recipes = {}

    def collect(module):
        for recipe in module["recipes"].values():
            recipes[recipe["namepath"]] = recipe
        for child in module["modules"].values():
            collect(child)

    collect(json.loads(result.stdout))
    return recipes


def recipe_call_count(parent, child, recipe):
    module = parent.rsplit("::", 1)[0] if "::" in parent else ""
    count = sum(
        (f"{module}::{dependency['recipe']}" if module else dependency["recipe"]) == child
        and not dependency["arguments"]
        for dependency in recipe["dependencies"]
    )
    commands = {f"just {child}", f"just {child.replace('::', ' ')}"}
    # Require a literal command with no interpolation, conditional, ignored error,
    # shell suffix or arguments. Do not mistake a comment/echo for an invocation.
    count += sum(
        len(line) == 1 and isinstance(line[0], str) and line[0].strip() in commands
        for line in recipe["body"]
    )
    return count


def validate_ownership(suite, recipes):
    roots = [task for lane in suite["lanes"].values() for task in lane]
    assert len(roots) == len(set(roots)), "duplicate CI task ownership"
    roots += [task for group in suite["external_tasks"].values() for task in group]
    indirect = suite["nested_tasks"]
    direct = suite["recipe_nested_tasks"]
    assert not indirect.keys() & direct.keys(), "ambiguous nested task owner"
    nesting = {**indirect, **direct}
    for parent, children in nesting.items():
        assert parent in recipes, f"missing recipe: {parent}"
        assert children and len(children) == len(set(children)), f"duplicate/empty nesting: {parent}"
        for child in children:
            assert child in recipes, f"missing recipe: {child}"
            if parent in direct:
                count = recipe_call_count(parent, child, recipes[parent])
                assert count == 1, f"{parent} must invoke {child} exactly once; found {count}"

    reachable = set()

    def visit(task, ancestors):
        assert task in recipes, f"missing recipe: {task}"
        assert task not in ancestors, f"nested task cycle: {(*ancestors, task)}"
        reachable.add(task)
        for child in nesting.get(task, []):
            visit(child, (*ancestors, task))

    for task in roots:
        visit(task, ())
    assert nesting.keys() <= reachable, f"unowned nested tasks: {nesting.keys() - reachable}"
    return reachable, nesting


def validate_required_tiers(suite, invariants, nesting):
    def expand(task):
        yield task
        for child in nesting.get(task, []):
            yield from expand(child)

    for invariant in invariants["invariants"]:
        tier = invariant.get("required_tier")
        if tier is None:
            continue
        assert tier in suite["tiers"], f"unknown required tier: {tier}"
        counts = Counter(
            task
            for lane in suite["tiers"][tier]
            for root in suite["lanes"][lane]
            for task in expand(root)
        )
        for task in invariant["tasks"]:
            assert counts[task] == 1, (
                f"{invariant['id']} requires {task} once in {tier}; found {counts[task]}"
            )
