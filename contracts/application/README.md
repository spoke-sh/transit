# Application declaration grammar

Use the public [application SQL reference](../../docs/reference/sql/application.md)
for every declaration, required options and a complete offline example.

[Application v1](../APPLICATION_V1.md) defines the selected bounded model.
`Application.g4` is its independent syntactic reference; it does not authorize or
publish anything. Option meanings, complete reference validation and embedded
query compilation belong to `transit-station-app` and Fuze. The broader
[SQL grammar](../sql/README.md) retains its separate capability inventory.

Run `just test::application-grammar` in the Nix environment. The proof regenerates
ANTLR with the existing pinned SQL tools, compares a separate parse-tree adapter
to the actual compiler, changes typed presentation data, and checks semantic
round-trip and whole-program rejection. The generated JSON Schema comes directly
from the package's public Zig types; it is a structural boundary, followed by
the owning semantic validator before publication.
