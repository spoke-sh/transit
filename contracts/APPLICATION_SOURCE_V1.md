# Application source contract

[transitc](https://github.com/spoke-sh/transitc/blob/main/contracts/APPLICATION_SOURCE_V1.md)
owns source syntax, compilation, build and test orchestration, and the independent
[source grammar, model and corpus](https://github.com/spoke-sh/transitc/blob/main/contracts/application-source/README.md).
It depends on Transit's SQL frontend, protocol types and compiled-case test host.
Transit has no source compiler or dependency on transitc. Runtime SQL, migration
application and test execution retain their Transit owners. The extraction does
not reinterpret accepted SQL or immutable migration history.
