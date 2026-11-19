# Typed application targets

Synthetic Machine and Site targets share raw ID `7` but have distinct nominal
source domains and public Table signatures. The source specializes each closed
variant into its selected insert. `expected.sql` is independently hand-expanded;
both Tables contain exactly row `7`. It contains no source controls or type tags.

The build proof checks offline cold/warm builds and rejects swapped ID domains,
Table handles and a bad unselected arm before publication. It removes the source
before ordinary SQL execution, compares the independent SQL, restarts the real
service and checks current authorization after credential revocation.

The Table test command runs both constructors in isolated cases, checks complete
rows, authoritative insert counts and a real duplicate-key refusal. The first
case sees Machine rows `7` and `9` and no Site rows; the second sees Site row `7`
and no Machine rows. These are independent expectations, not generated outputs.
Source typing establishes no resource existence or runtime authorization.
