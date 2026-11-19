# Application Table test fixtures

The source composes two independent cases with the same Table name. The first
case creates rows 7/9, preserves NULL, checks counts and rejects a duplicate key;
the second sees only row 3. `expected.sql` is independently hand-written canonical
SQL for the first case, including its deliberately refused write. Assertions
and test controls are absent from executable SQL. The fixture is an oracle,
not evidence that a runtime check has executed.
