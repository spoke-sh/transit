# Application source grammar

[TransitSource.g4](TransitSource.g4) defines the bounded `.transit` source
profile in [Application source v1](../APPLICATION_SOURCE_V1.md). Its root is
`sourceFile`, including complete input consumption. Imports, modules, interfaces,
domains, closed variants, typed resource exports, targets and test controls are compile-time forms, not ordinary runtime SQL.

The grammar imports [TransitExtensions.g4](../sql/TransitExtensions.g4) with the
same pinned ANTLR 4.13.2 tools. Source overrides add typed holes and narrow the
statement root to Table/Stream/Queue creation, literal mutations and log appends,
and finite single-Table queries. Recursive logical types and literals remain available; compile-time
TYPE arguments still have their smaller, separately checked set. The copied
type/literal extension productions must follow changes in their SQL owner.
Unknown scalar type words remain a later binding refusal; structured type forms
are checked here. Cast recognition likewise does not enable native Table casts.
The ordinary SQL and interface/UI grammar roots remain separate.

Public Queue program templates include ordered expressions, Table reads,
guarded branches and atomic writes/appends. Their expanded SQL uses the installed
program parser and type binder. Lifecycle controls remain separate statements.
The reference checker also enforces atomic placement in unused bodies. Finite
Stream reads and bounded WORKFLOW assertions share the existing test root;
assertion controls do not enter emitted SQL.

Source names are contextual ASCII words. SQL retains its own reserved names and
quoted identifier rules. A source hole records its role (identifier, type, value,
matching Stream/Queue target, or an operand whose binding may be a column or value)
and UTF-8 byte span.
Neither grammar acceptance nor a hole's syntactic role grants a binding, policy
right or runtime capability. Stage checks, quotas and supported execution remain
with the source contract and ordinary statement owners.

[corpus.json](corpus.json) is authored independently of the Zig parser. It fixes
positive/negative syntax, selected AST expectations, rejection coordinates and
later compilation outcomes. The [verification driver](../../tests/query/application_source/README.md)
compares the ANTLR tree with actual production syntax, source round-trips and
compiled products. Generated parsers and run records are ignored artifacts.
This finite correspondence check is not an exhaustive language proof, an
execution qualification, a TLA+ model result or a Lean theorem.

The corpus includes public/imported nominal domains, three-component constructors,
exhaustive MATCH syntax, hygienic binders, named instance results, Table signatures
and export forwarding. Syntax acceptance remains distinct from duplicate domain
identity, wrong argument/interface, nominal SQL operand and exhaustiveness checks.
Source type words remain contextual except at the explicit built-in kind sites.

[TypedTarget.lean](TypedTarget.lean) owns three separate source/action laws, with
premises and exclusions in its header and the source contract. The dedicated
`test::application-source-types` task also compares finite independent typed
expectations with production checked operands and erased SQL; it does not replace
grammar correspondence or real CLI execution. Its audit rejects missing theorem
output, incomplete proofs and unreviewed axioms. The selection law uses `propext` and Lean's quotient
soundness axiom through the library's finite-list filter/count lemmas; the other
two laws permit only `propext`. No application or compiler correctness axiom is admitted.
