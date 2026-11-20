# Transit compiled-case test protocol

Pure types and bounded encoding/validation for SQL steps, typed expectations and
native test observations. The [test-host contract](../../../contracts/TEST_HOST_V1.md)
owns the process boundary. This package imports SQL frontend and protocol types;
it has no source compiler, workspace, runtime or I/O dependency.

[transitc](https://github.com/spoke-sh/transitc) compiles source and orchestrates
suites. Transit executes already compiled cases through its isolated native test
host. Neither this package nor the runtime resolves or evaluates source modules.
