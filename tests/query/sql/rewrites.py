"""Check complete Lean proofs; omissions and sorry axioms fail qualification."""
from runner.paths import ROOT
import re
import subprocess

SPECS = (
    (
        ROOT / 'contracts/sql/FuzeRewrite.lean',
        {
            'filter_reorder_preserves_selection',
            'projection_pruning_preserves_rows',
            'predicate_pushdown_through_projection',
            'pushdown_preserves_downstream_errors',
        },
    ),
    (
        ROOT / 'contracts/sql/FuzeCell.lean',
        {
            'kleene_and_comm',
            'kleene_or_comm',
            'kleene_de_morgan_and',
            'cell_error_never_selects',
            'is_not_distinct_from_refl',
            'where_and_equiv_sequential',
        },
    ),
    (
        ROOT / 'contracts/sql/SchemaProjection.lean',
        {
            'add_column_preserves_existing_projection',
            'drop_column_commutes_with_projection',
            'compaction_rewrite_preserves_projection',
        },
    ),
    (
        ROOT / 'contracts/sql/CollationOrder.lean',
        {
            'collation_le_refl',
            'collation_le_trans',
            'collation_le_total',
            'umbra_prefix_reflects_lt',
            'zonemap_min_pruning_sound',
            'zonemap_max_pruning_sound',
        },
    ),
)

total_theorems = 0
for source, required in SPECS:
    result = subprocess.run(['lean', str(source)], text=True, capture_output=True)
    assert result.returncode == 0, f"{source.name}:\n{result.stdout}{result.stderr}"
    assert not result.stderr and 'sorryAx' not in result.stdout and 'warning:' not in result.stdout, f"{source.name}:\n{result.stdout}{result.stderr}"
    names = re.findall(r'^#print axioms (\w+)$', source.read_text(), re.M)
    assert set(names) == required and all(name in result.stdout for name in names), f"{source.name}:\n{result.stdout}"
    for axioms in re.findall(r'depends on axioms: \[(.*?)\]', result.stdout):
        assert set(axioms.split(', ')) <= {'propext'}, f"{source.name}:\n{result.stdout}"
    print(result.stdout, end='')
    total_theorems += len(names)

print(f'Lean: {total_theorems} named theorems across {len(SPECS)} specifications checked, no sorry axioms or warnings.')
