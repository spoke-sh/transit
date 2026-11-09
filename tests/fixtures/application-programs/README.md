# Downstream application program inputs

These three SQL files are exact copies of Platform's intended fresh-installation
history at `e79691c9972084965bf4a777e7cca6939b6ad815`. They are source inputs,
not credentials, a deployed installation or a claim that the whole application
executes. The [implementation plan](../../../docs/roadmap/downstream-application-language.md)
records the owning contracts and qualification gates.

`inputs.json` freezes byte counts, SHA-256 hashes and independently reviewed
top-level statement line numbers: nine identity statements, 29 sign-in statements
and five publication statements. Internal dataflow instructions are not migration
steps. The original consumer owns the SQL; changes to this fixture require an
explicitly reconciled consumer revision and new source attribution.

Expected application behavior comes from Platform's
[sign-in contract](https://github.com/spoke-sh/platform/blob/e79691c9972084965bf4a777e7cca6939b6ad815/contracts/github-signin-application-v1.md).
Any provider fixtures must use synthetic secrets and independent responses.
Framing, compilation, installation, runtime outcomes and published-artifact
qualification are separate checks; preserving these files qualifies none of them.
